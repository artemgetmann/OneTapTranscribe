import Combine
import Foundation
import OSLog
#if os(iOS)
import AVFoundation
import UIKit
#endif

@MainActor
final class RecordingStateStore: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isUploading = false
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var statusMessage = "No activity running"
    @Published private(set) var lastTranscript: String?
    @Published private(set) var hasPendingClipboardCopy = false

    private let liveActivityService: LiveActivityService
    private let recorderService: RecorderServiceProtocol
    private let transcriptionQueue: TranscriptionQueue
    private let clipboardService: ClipboardService
    private let notificationService: NotificationServiceProtocol
    private let backgroundTaskService: BackgroundTaskServiceProtocol
    private var tickerTask: Task<Void, Never>?
    private var commandWatcherTask: Task<Void, Never>?
    private var lastObservedStartCommandAt: TimeInterval = 0
    private var lastObservedStopCommandAt: TimeInterval = 0
    private var nextStartRetryAt: TimeInterval = 0
    private var nextDeferredTranscriptionRetryAt: TimeInterval = 0
    private var isProcessingRemoteStart = false
    private var isProcessingRemoteStop = false
    private var isProcessingDeferredTranscriptions = false
    private var deferredTranscriptionRetryAttempt = 0
    private var pendingClipboardText: String?
    private var pendingTranscriptionFiles: [URL] = []
#if os(iOS)
    private var audioInterruptionObserver: NSObjectProtocol?
#endif
    private let logger = Logger(subsystem: "test.OneTapTranscribe", category: "RecordingStateStore")

    init(
        liveActivityService: LiveActivityService,
        recorderService: RecorderServiceProtocol,
        transcriptionQueue: TranscriptionQueue,
        clipboardService: ClipboardService,
        notificationService: NotificationServiceProtocol,
        backgroundTaskService: BackgroundTaskServiceProtocol
    ) {
        self.liveActivityService = liveActivityService
        self.recorderService = recorderService
        self.transcriptionQueue = transcriptionQueue
        self.clipboardService = clipboardService
        self.notificationService = notificationService
        self.backgroundTaskService = backgroundTaskService
        // Resume from explicit consumed markers so command taps made while app was cold-started
        // are not discarded as "already observed" during initialization.
        self.lastObservedStartCommandAt = LiveActivityCommandStore.latestConsumedStartRequestTimestamp()
        self.lastObservedStopCommandAt = LiveActivityCommandStore.latestConsumedStopRequestTimestamp()
        // Restore pending clipboard state in case previous copy attempt happened while app was backgrounded.
        self.pendingClipboardText = DeferredClipboardStore.load()
        self.hasPendingClipboardCopy = self.pendingClipboardText?.isEmpty == false
        self.pendingTranscriptionFiles = DeferredTranscriptionStore.load()
        if !self.pendingTranscriptionFiles.isEmpty {
            self.statusMessage = "Pending transcription queued. Retrying automatically."
        }
        installAudioInterruptionObserver()
        startCommandWatcher()
        Task { [weak self] in
            await self?.processPendingTranscriptionsIfNeeded(force: true)
        }
    }

    deinit {
        tickerTask?.cancel()
        commandWatcherTask?.cancel()
#if os(iOS)
        if let audioInterruptionObserver {
            NotificationCenter.default.removeObserver(audioInterruptionObserver)
        }
#endif
    }

    func startRecording() async {
        guard !isRecording else { return }
        logger.info("startRecording requested isRecording=\(self.isRecording, privacy: .public) isUploading=\(self.isUploading, privacy: .public)")

        do {
            try await recorderService.startRecording()
            if liveActivityService.canStartActivities() {
                try liveActivityService.startLiveActivity(startTime: Date())
            }

            elapsedSeconds = 0
            isRecording = true
            isUploading = false
            statusMessage = liveActivityService.canStartActivities()
                ? "Recording started. Live Activity is running."
                : "Recording started. Live Activities are disabled."
            logger.info("startRecording succeeded liveActivityAvailable=\(self.liveActivityService.canStartActivities(), privacy: .public)")
            startTicker()
        } catch {
            // Keep state sane if one dependency starts successfully and the next one fails.
            _ = try? await recorderService.stopRecording()
            statusMessage = "Failed to start: \(error.localizedDescription)"
            logger.error("startRecording failed error=\(error.localizedDescription, privacy: .public)")
        }
    }

    func stopRecording() async {
        guard isRecording else { return }
        logger.info("stopRecording requested elapsed=\(self.elapsedSeconds, privacy: .public)")
        let backgroundToken = backgroundTaskService.beginTask(named: "OneTapTranscribe.StopAndUpload")
        defer { backgroundTaskService.endTask(backgroundToken) }

        // Freeze timer first so UI and widget stop incrementing immediately.
        stopTicker()
        isRecording = false
        isUploading = true
        statusMessage = "Stopping recording..."
        await liveActivityService.updateLiveActivity(
            elapsedSeconds: elapsedSeconds,
            isUploading: true
        )

        do {
            let audioFileURL = try await recorderService.stopRecording()
            await liveActivityService.stopLiveActivity()
            isUploading = false

            // Defensive guard in case recorder stops without producing a file.
            guard let audioFileURL else {
                elapsedSeconds = 0
                statusMessage = "Stopped. Recording file was not created."
                return
            }

            statusMessage = "Queued for transcription..."
            enqueueDeferredTranscription(audioFileURL)
            await processPendingTranscriptionsIfNeeded(force: true)
        } catch {
            // Ensure lock screen UI is not orphaned if recorder teardown throws.
            await liveActivityService.stopLiveActivity()
            isUploading = false
            statusMessage = "Stop failed: \(error.localizedDescription)"
            logger.error("stopRecording failed error=\(error.localizedDescription, privacy: .public)")
            await notificationService.notifyTranscriptionResult(
                success: false,
                body: error.localizedDescription,
                transcriptForCopy: nil
            )
        }

        elapsedSeconds = 0
    }

    func prepareNotifications() async {
        await notificationService.requestAuthorizationIfNeeded()
    }

    func copyLastTranscriptToClipboard() {
        guard let lastTranscript, !lastTranscript.isEmpty else { return }
        let copied = clipboardService.copy(lastTranscript)
        statusMessage = copied ? "Transcript copied again." : "Copy failed."
    }

    func handleAppDidBecomeActive() {
        let pending = pendingClipboardText ?? DeferredClipboardStore.load()
        if let pending, !pending.isEmpty {
            let copied = clipboardService.copy(pending)
            if copied {
                self.pendingClipboardText = nil
                DeferredClipboardStore.clear()
                hasPendingClipboardCopy = false
                statusMessage = "Transcript copied to clipboard."
            } else {
                // Keep durable fallback so user can retry after returning to foreground again.
                DeferredClipboardStore.save(pending)
                self.pendingClipboardText = pending
                hasPendingClipboardCopy = true
                statusMessage = "Transcript ready, but copy failed."
            }
        }

        // Consume any pending control-widget command immediately on foreground transition.
        Task { [weak self] in
            await self?.consumeRemoteCommandsIfNeeded()
            await self?.processPendingTranscriptionsIfNeeded(force: true)
        }
    }

    private func startTicker() {
        stopTicker()
        tickerTask = Task { [weak self] in
            // Async loop avoids RunLoop timer ownership in the view layer.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await self?.tick()
            }
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    private func tick() async {
        guard isRecording else { return }
        elapsedSeconds += 1

        await liveActivityService.updateLiveActivity(
            elapsedSeconds: elapsedSeconds,
            isUploading: false
        )

        await consumeRemoteCommandsIfNeeded()
    }

    private func startCommandWatcher() {
        commandWatcherTask?.cancel()
        commandWatcherTask = Task { [weak self] in
            // Keep command handling alive while app process is running,
            // even when no recording ticker is active.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await self?.consumeRemoteCommandsIfNeeded()
                await self?.processPendingTranscriptionsIfNeeded()
            }
        }
    }

    private func consumeRemoteCommandsIfNeeded() async {
        await consumeRemoteStartCommandIfNeeded()
        await consumeRemoteStopCommandIfNeeded()
    }

    private func consumeRemoteStartCommandIfNeeded() async {
        guard !isRecording, !isUploading, !isProcessingRemoteStart else { return }
        guard Date().timeIntervalSince1970 >= nextStartRetryAt else { return }

        let observedTimestamp = LiveActivityCommandStore.latestStartRequestTimestamp()
        guard observedTimestamp > lastObservedStartCommandAt else { return }
        isProcessingRemoteStart = true

        Task { [weak self] in
            guard let self else { return }
            self.logger.info("consumeRemoteStartCommand observedTimestamp=\(observedTimestamp, privacy: .public) lastObserved=\(self.lastObservedStartCommandAt, privacy: .public)")
            await self.startRecording()
            if self.isRecording {
                self.lastObservedStartCommandAt = observedTimestamp
                LiveActivityCommandStore.markStartRequestConsumed(observedTimestamp)
                self.nextStartRetryAt = 0
            } else {
                // Keep command unconsumed so a foreground transition can retry the same request.
                self.nextStartRetryAt = Date().timeIntervalSince1970 + 1.5
                self.logger.error("consumeRemoteStartCommand startFailed willRetry timestamp=\(observedTimestamp, privacy: .public)")
            }
            self.isProcessingRemoteStart = false
        }
    }

    private func consumeRemoteStopCommandIfNeeded() async {
        guard isRecording, !isProcessingRemoteStop else { return }

        let observedTimestamp = LiveActivityCommandStore.latestStopRequestTimestamp()
        guard observedTimestamp > lastObservedStopCommandAt else { return }
        logger.info("consumeRemoteStopCommand observedTimestamp=\(observedTimestamp, privacy: .public) lastObserved=\(self.lastObservedStopCommandAt, privacy: .public)")

        lastObservedStopCommandAt = observedTimestamp
        LiveActivityCommandStore.markStopRequestConsumed(observedTimestamp)
        isProcessingRemoteStop = true

        // Run stop flow off the ticker task. Otherwise stopTicker() would cancel this same task.
        Task { [weak self] in
            guard let self else { return }
            await self.stopRecording()
            self.isProcessingRemoteStop = false
        }
    }

    private func enqueueDeferredTranscription(_ fileURL: URL) {
        let exists = pendingTranscriptionFiles.contains(where: { $0.path == fileURL.path })
        guard !exists else { return }
        pendingTranscriptionFiles.append(fileURL)
        DeferredTranscriptionStore.save(pendingTranscriptionFiles)
        logger.info("enqueueDeferredTranscription count=\(self.pendingTranscriptionFiles.count, privacy: .public) path=\(fileURL.path, privacy: .public)")
    }

    private func processPendingTranscriptionsIfNeeded(force: Bool = false) async {
        guard !isProcessingDeferredTranscriptions else { return }
        guard !pendingTranscriptionFiles.isEmpty else { return }
        guard force || Date().timeIntervalSince1970 >= nextDeferredTranscriptionRetryAt else { return }

        isProcessingDeferredTranscriptions = true
        defer { isProcessingDeferredTranscriptions = false }

        while !pendingTranscriptionFiles.isEmpty {
            let audioFileURL = pendingTranscriptionFiles[0]

            guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
                logger.error("processPendingTranscriptions missingFile path=\(audioFileURL.path, privacy: .public)")
                pendingTranscriptionFiles.removeFirst()
                DeferredTranscriptionStore.save(pendingTranscriptionFiles)
                continue
            }

            do {
                let transcript = try await transcriptionQueue.enqueue(audioFileURL: audioFileURL)

                // Remove durable job only after we have a transcript.
                pendingTranscriptionFiles.removeFirst()
                DeferredTranscriptionStore.save(pendingTranscriptionFiles)
                deferredTranscriptionRetryAttempt = 0
                nextDeferredTranscriptionRetryAt = 0
                try? FileManager.default.removeItem(at: audioFileURL)

                await handleSuccessfulTranscription(transcript)
            } catch {
                deferredTranscriptionRetryAttempt += 1
                let retryable = isRetryableTranscriptionError(error)
                let delaySeconds = nextDeferredRetryDelaySeconds(retryable: retryable)
                nextDeferredTranscriptionRetryAt = Date().timeIntervalSince1970 + delaySeconds

                if retryable {
                    statusMessage = "Transcription queued. Retrying automatically..."
                } else {
                    statusMessage = "Transcription queued. Waiting for backend/auth fix, then retrying automatically."
                }

                // Build log message in steps to keep Swift type-checking predictable.
                let errorDescription = error.localizedDescription
                let logLine = "processPendingTranscriptions failed retryable=\(retryable) delaySeconds=\(delaySeconds) attempt=\(deferredTranscriptionRetryAttempt) error=\(errorDescription)"
                logger.error("\(logLine, privacy: .public)")
                break
            }
        }
    }

    private func handleSuccessfulTranscription(_ transcript: String) async {
        lastTranscript = transcript
        let copyResult = copyTranscriptRespectingLifecycle(transcript)
        switch copyResult {
        case .copied:
            statusMessage = "Stopped. Transcript copied to clipboard."
            logger.info("transcription completed copyResult=copied transcriptLength=\(transcript.count, privacy: .public)")
            await notificationService.notifyTranscriptionResult(
                success: true,
                body: "Transcript copied to clipboard.",
                transcriptForCopy: nil
            )
        case .deferred:
            statusMessage = "Stopped. Transcript ready. Tap notification to open app and copy."
            logger.info("transcription completed copyResult=deferred transcriptLength=\(transcript.count, privacy: .public)")
            await notificationService.notifyTranscriptionResult(
                success: true,
                body: "Transcript ready. Tap Open app & copy.",
                transcriptForCopy: transcript
            )
        case .failed:
            statusMessage = "Stopped. Transcript ready."
            logger.info("transcription completed copyResult=failed transcriptLength=\(transcript.count, privacy: .public)")
            await notificationService.notifyTranscriptionResult(
                success: true,
                body: "Transcript is ready.",
                transcriptForCopy: nil
            )
        }
    }

    private func isRetryableTranscriptionError(_ error: Error) -> Bool {
        if let apiError = error as? APIClientError {
            switch apiError {
            case let .server(_, _, _, retryable):
                return retryable
            case .network, .invalidResponse:
                return true
            case .invalidAudioFile, .emptyTranscript:
                return false
            }
        }
        return false
    }

    private func nextDeferredRetryDelaySeconds(retryable: Bool) -> TimeInterval {
        guard retryable else { return 60 }
        // Start fast, then back off to avoid hammering Render/OpenAI during sustained outages.
        let power = min(deferredTranscriptionRetryAttempt, 6)
        let exponential = pow(2.0, Double(power))
        return max(5, min(90, exponential))
    }

    private func installAudioInterruptionObserver() {
#if os(iOS)
        audioInterruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.isRecording else { return }

                let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
                guard let type = AVAudioSession.InterruptionType(rawValue: rawType),
                      type == .began else { return }

                // Calls/Siri can preempt the audio session. Auto-stop immediately so
                // we preserve the already captured audio and push it to transcription.
                self.logger.info("audio interruption began; auto-stopping active recording")
                await self.stopRecording()
            }
        }
#endif
    }

    private enum ClipboardCopyResult {
        case copied
        case deferred
        case failed
    }

    private func copyTranscriptRespectingLifecycle(_ transcript: String) -> ClipboardCopyResult {
        guard !transcript.isEmpty else { return .failed }

#if os(iOS)
        // Background clipboard writes are not reliable on iOS.
        // Force deferred path so notification action/app-open fallback is always available.
        if UIApplication.shared.applicationState != .active {
            pendingClipboardText = transcript
            DeferredClipboardStore.save(transcript)
            hasPendingClipboardCopy = true
            return .deferred
        }
#endif

        let copied = clipboardService.copy(transcript)
        if copied {
            pendingClipboardText = nil
            DeferredClipboardStore.clear()
            hasPendingClipboardCopy = false
            return .copied
        }
        // Keep fallback path for OS-rejected background writes.
        pendingClipboardText = transcript
        DeferredClipboardStore.save(transcript)
        hasPendingClipboardCopy = true
        return .deferred
    }
}

extension RecordingStateStore {
    static var preview: RecordingStateStore {
        RecordingStateStore(
            liveActivityService: LiveActivityService(),
            recorderService: RecorderService(),
            transcriptionQueue: TranscriptionQueue(
                apiClient: APIClient(baseURL: AppConfig.transcriptionBaseURL)
            ),
            clipboardService: ClipboardService(),
            notificationService: NotificationService(),
            backgroundTaskService: BackgroundTaskService()
        )
    }
}
