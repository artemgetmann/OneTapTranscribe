import Combine
import Foundation
#if canImport(UIKit)
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
    private var lastObservedStopCommandAt: TimeInterval = 0
    private var isProcessingRemoteStop = false
    private var pendingClipboardText: String?

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
        // Avoid replaying stale stop commands that may exist from previous sessions.
        self.lastObservedStopCommandAt = LiveActivityCommandStore.latestStopRequestTimestamp()
    }

    deinit {
        tickerTask?.cancel()
    }

    func startRecording() async {
        guard !isRecording else { return }

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
            startTicker()
        } catch {
            // Keep state sane if one dependency starts successfully and the next one fails.
            _ = try? await recorderService.stopRecording()
            statusMessage = "Failed to start: \(error.localizedDescription)"
        }
    }

    func stopRecording() async {
        guard isRecording else { return }
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
            do {
                // Queue retries transient failures to survive poor network and handoffs.
                let transcript = try await transcriptionQueue.enqueue(audioFileURL: audioFileURL)
                lastTranscript = transcript
                let copyResult = copyTranscriptRespectingLifecycle(transcript)
                switch copyResult {
                case .copied:
                    statusMessage = "Stopped. Transcript copied to clipboard."
                    await notificationService.notifyTranscriptionResult(
                        success: true,
                        body: "Transcript copied to clipboard."
                    )
                case .deferred:
                    statusMessage = "Stopped. Transcript ready. Open app to copy."
                    await notificationService.notifyTranscriptionResult(
                        success: true,
                        body: "Transcript ready. Open app to copy."
                    )
                case .failed:
                    statusMessage = "Stopped. Transcript ready."
                    await notificationService.notifyTranscriptionResult(
                        success: true,
                        body: "Transcript is ready."
                    )
                }
            } catch {
                statusMessage = "Stopped. Transcription failed: \(error.localizedDescription)"
                await notificationService.notifyTranscriptionResult(
                    success: false,
                    body: error.localizedDescription
                )
            }
        } catch {
            // Ensure lock screen UI is not orphaned if recorder teardown throws.
            await liveActivityService.stopLiveActivity()
            isUploading = false
            statusMessage = "Stop failed: \(error.localizedDescription)"
            await notificationService.notifyTranscriptionResult(
                success: false,
                body: error.localizedDescription
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
        guard let pendingClipboardText, !pendingClipboardText.isEmpty else { return }
        let copied = clipboardService.copy(pendingClipboardText)
        if copied {
            self.pendingClipboardText = nil
            hasPendingClipboardCopy = false
            statusMessage = "Transcript copied to clipboard."
        } else {
            statusMessage = "Transcript ready, but copy failed."
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

        await consumeRemoteStopCommandIfNeeded()
    }

    private func consumeRemoteStopCommandIfNeeded() async {
        guard isRecording, !isProcessingRemoteStop else { return }

        let observedTimestamp = LiveActivityCommandStore.latestStopRequestTimestamp()
        guard observedTimestamp > lastObservedStopCommandAt else { return }

        lastObservedStopCommandAt = observedTimestamp
        isProcessingRemoteStop = true

        // Run stop flow off the ticker task. Otherwise stopTicker() would cancel this same task.
        Task { [weak self] in
            guard let self else { return }
            await self.stopRecording()
            self.isProcessingRemoteStop = false
        }
    }

    private enum ClipboardCopyResult {
        case copied
        case deferred
        case failed
    }

    private func copyTranscriptRespectingLifecycle(_ transcript: String) -> ClipboardCopyResult {
        guard !transcript.isEmpty else { return .failed }
        guard isAppActiveForClipboardWrites() else {
            pendingClipboardText = transcript
            hasPendingClipboardCopy = true
            return .deferred
        }
        let copied = clipboardService.copy(transcript)
        return copied ? .copied : .failed
    }

    private func isAppActiveForClipboardWrites() -> Bool {
#if canImport(UIKit)
        return UIApplication.shared.applicationState == .active
#else
        return true
#endif
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
