import Combine
import Foundation

@MainActor
final class RecordingStateStore: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isUploading = false
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var statusMessage = "No activity running"
    @Published private(set) var lastTranscript: String?

    private let liveActivityService: LiveActivityService
    private let recorderService: RecorderServiceProtocol
    private let transcriptionQueue: TranscriptionQueue
    private let clipboardService: ClipboardService
    private var tickerTask: Task<Void, Never>?
    private var lastObservedStopCommandAt: TimeInterval = 0
    private var isProcessingRemoteStop = false

    init(
        liveActivityService: LiveActivityService,
        recorderService: RecorderServiceProtocol,
        transcriptionQueue: TranscriptionQueue,
        clipboardService: ClipboardService
    ) {
        self.liveActivityService = liveActivityService
        self.recorderService = recorderService
        self.transcriptionQueue = transcriptionQueue
        self.clipboardService = clipboardService
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
                let copied = clipboardService.copy(transcript)
                statusMessage = copied
                    ? "Stopped. Transcript copied to clipboard."
                    : "Stopped. Transcript ready."
            } catch {
                statusMessage = "Stopped. Transcription failed: \(error.localizedDescription)"
            }
        } catch {
            // Ensure lock screen UI is not orphaned if recorder teardown throws.
            await liveActivityService.stopLiveActivity()
            isUploading = false
            statusMessage = "Stop failed: \(error.localizedDescription)"
        }

        elapsedSeconds = 0
    }

    func copyLastTranscriptToClipboard() {
        guard let lastTranscript, !lastTranscript.isEmpty else { return }
        let copied = clipboardService.copy(lastTranscript)
        statusMessage = copied ? "Transcript copied again." : "Copy failed."
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
        defer { isProcessingRemoteStop = false }

        // Reuse the exact same stop pipeline so behavior remains consistent.
        await stopRecording()
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
            clipboardService: ClipboardService()
        )
    }
}
