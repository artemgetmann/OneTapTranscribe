import Foundation
import OSLog

/// Serialization point for transcription jobs.
/// Actor isolation keeps queue behavior deterministic when multiple jobs are enqueued.
actor TranscriptionQueue {
    struct RetryPolicy: Sendable {
        let maxAttempts: Int
        let backoffSeconds: [UInt64]
        let minimumRetryWindowSeconds: TimeInterval

        static let `default` = RetryPolicy(
            // About 37 seconds total backoff to ride through Render free-tier cold starts.
            maxAttempts: 8,
            backoffSeconds: [1, 2, 4, 6, 8, 8, 8],
            minimumRetryWindowSeconds: 30
        )
    }

    private let apiClient: APIClientProtocol
    private let retryPolicy: RetryPolicy
    private let logger = Logger(subsystem: "test.OneTapTranscribe", category: "TranscriptionQueue")

    init(
        apiClient: APIClientProtocol,
        retryPolicy: RetryPolicy = .default
    ) {
        self.apiClient = apiClient
        self.retryPolicy = retryPolicy
    }

    func enqueue(audioFileURL: URL) async throws -> String {
        var attempt = 0
        let startedAt = Date().timeIntervalSince1970

        while true {
            attempt += 1
            do {
                // For MVP we process immediately in actor-isolated FIFO order.
                let result = try await apiClient.transcribe(
                    audioFileURL: audioFileURL,
                    model: "whisper-1",
                    language: nil,
                    prompt: nil
                )
                return result.text
            } catch {
                let elapsedSeconds = Date().timeIntervalSince1970 - startedAt
                // Guard against failing too fast when the backend is waking from cold start.
                let retryWindowOpen = elapsedSeconds < retryPolicy.minimumRetryWindowSeconds
                let canRetry = isRetryable(error)
                    && attempt < retryPolicy.maxAttempts
                    && retryWindowOpen
                guard canRetry else {
                    logger.error("transcription enqueue failed attempt=\(attempt, privacy: .public) retryable=\(self.isRetryable(error), privacy: .public) error=\(error.localizedDescription, privacy: .public)")
                    throw error
                }

                let backoffIndex = min(attempt - 1, retryPolicy.backoffSeconds.count - 1)
                let delaySeconds = retryPolicy.backoffSeconds[backoffIndex]
                let remainingWindow = max(
                    0,
                    retryPolicy.minimumRetryWindowSeconds - elapsedSeconds
                )
                let boundedDelaySeconds = min(
                    delaySeconds,
                    UInt64(remainingWindow.rounded(.down))
                )
                let finalDelaySeconds = max(1, boundedDelaySeconds)
                logger.info("transcription enqueue retrying attempt=\(attempt, privacy: .public) delaySeconds=\(finalDelaySeconds, privacy: .public)")
                // Backoff gives Wi-Fi->cellular handoff enough time to settle.
                try? await Task.sleep(nanoseconds: finalDelaySeconds * 1_000_000_000)
            }
        }
    }

    private func isRetryable(_ error: Error) -> Bool {
        if let apiError = error as? APIClientError {
            switch apiError {
            case let .server(_, _, _, retryable):
                return retryable
            case .network:
                return true
            case .invalidResponse:
                return true
            case .invalidAudioFile, .emptyTranscript:
                return false
            }
        }

        // Default unknown failures to non-retryable to avoid infinite loops on logic bugs.
        return false
    }
}
