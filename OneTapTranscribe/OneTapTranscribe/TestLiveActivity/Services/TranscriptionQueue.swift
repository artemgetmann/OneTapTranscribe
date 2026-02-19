import Foundation
import OSLog

/// Serialization point for transcription jobs.
/// Actor isolation keeps queue behavior deterministic when multiple jobs are enqueued.
actor TranscriptionQueue {
    struct RetryPolicy: Sendable {
        let maxAttempts: Int
        let backoffSeconds: [UInt64]

        static let `default` = RetryPolicy(
            // About 37 seconds total backoff to ride through Render free-tier cold starts.
            maxAttempts: 8,
            backoffSeconds: [1, 2, 4, 6, 8, 8, 8]
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
                let canRetry = isRetryable(error) && attempt < retryPolicy.maxAttempts
                guard canRetry else {
                    logger.error("transcription enqueue failed attempt=\(attempt, privacy: .public) retryable=\(self.isRetryable(error), privacy: .public) error=\(error.localizedDescription, privacy: .public)")
                    throw error
                }

                let backoffIndex = min(attempt - 1, retryPolicy.backoffSeconds.count - 1)
                let delaySeconds = retryPolicy.backoffSeconds[backoffIndex]
                logger.info("transcription enqueue retrying attempt=\(attempt, privacy: .public) delaySeconds=\(delaySeconds, privacy: .public)")
                // Backoff gives Wi-Fi->cellular handoff enough time to settle.
                try? await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
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
