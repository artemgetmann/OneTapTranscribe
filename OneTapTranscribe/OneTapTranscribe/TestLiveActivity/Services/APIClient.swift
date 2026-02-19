import Foundation
#if os(iOS)
import UIKit
#endif

enum APIClientError: LocalizedError {
    case invalidAudioFile
    case network(underlying: Error)
    case server(statusCode: Int, errorCode: String, message: String, retryable: Bool)
    case invalidResponse
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .invalidAudioFile:
            return "Audio file could not be read."
        case let .network(underlying):
            return "Network error: \(underlying.localizedDescription)"
        case let .server(_, _, message, _):
            return message
        case .invalidResponse:
            return "Server returned an invalid response."
        case .emptyTranscript:
            return "Server returned empty transcript text."
        }
    }
}

struct TranscriptionResult: Sendable {
    let text: String
    let durationSec: Double?
    let requestId: String?
}

protocol APIClientProtocol: Sendable {
    func transcribe(
        audioFileURL: URL,
        model: String,
        language: String?,
        prompt: String?
    ) async throws -> TranscriptionResult
}

/// Concrete network client for the backend proxy.
/// The app never talks to OpenAI directly; it only talks to our own proxy.
struct APIClient: APIClientProtocol, Sendable {
    private enum NetworkTuning {
        static let requestTimeoutSeconds: TimeInterval = 25
    }

    private let baseURLOverride: URL?
    private let clientTokenOverride: String?
    private let session: URLSession

    init(baseURL: URL? = nil, clientToken: String? = nil, session: URLSession = .shared) {
        self.baseURLOverride = baseURL
        self.clientTokenOverride = clientToken
        self.session = session
    }

    func transcribe(
        audioFileURL: URL,
        model: String = "whisper-1",
        language: String? = nil,
        prompt: String? = nil
    ) async throws -> TranscriptionResult {
        // Resolve backend config at request time so settings changes apply immediately.
        let resolvedBaseURL = baseURLOverride ?? AppConfig.transcriptionBaseURL
        let endpoint = resolvedBaseURL.appendingPathComponent("v1/transcribe")
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = makeRequest(endpoint: endpoint, boundary: boundary)
        if let token = resolvedClientToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data = try buildMultipartBody(
            audioFileURL: audioFileURL,
            model: model,
            language: language,
            prompt: prompt,
            boundary: boundary
        )
        let useBackgroundTransport = shouldUseBackgroundTransport()

        do {
            let (responseData, response): (Data, URLResponse)
            if useBackgroundTransport {
                let bodyFileURL = try writeMultipartBodyToTemporaryFile(data)
#if os(iOS)
                (responseData, response) = try await BackgroundUploadService.shared.upload(
                    request: request,
                    bodyFileURL: bodyFileURL
                )
#else
                request.httpBody = data
                (responseData, response) = try await session.data(for: request)
#endif
            } else {
                request.httpBody = data
                (responseData, response) = try await session.data(for: request)
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIClientError.invalidResponse
            }

            if (200..<300).contains(httpResponse.statusCode) {
                return try decodeSuccess(responseData: responseData)
            }

            throw decodeServerError(
                statusCode: httpResponse.statusCode,
                responseData: responseData
            )
        } catch let apiError as APIClientError {
            throw apiError
        } catch {
            throw APIClientError.network(underlying: error)
        }
    }

    private func resolvedClientToken() -> String? {
        if let override = clientTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines), !override.isEmpty {
            return override
        }
        return AppConfig.clientToken
    }

    private func makeRequest(endpoint: URL, boundary: String) -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        // Fail fast enough to allow queue retries to recover from Render cold starts.
        request.timeoutInterval = NetworkTuning.requestTimeoutSeconds
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "x-request-id")
        return request
    }

    private func writeMultipartBodyToTemporaryFile(_ body: Data) throws -> URL {
        let temporaryFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("transcribe-\(UUID().uuidString).multipart")
        try body.write(to: temporaryFileURL, options: .atomic)
        return temporaryFileURL
    }

    private func shouldUseBackgroundTransport() -> Bool {
#if os(iOS)
        UIApplication.shared.applicationState != .active
#else
        false
#endif
    }

    /// Construct multipart payload manually so we do not depend on third-party networking libs.
    private func buildMultipartBody(
        audioFileURL: URL,
        model: String,
        language: String?,
        prompt: String?,
        boundary: String
    ) throws -> Data {
        guard let audioData = try? Data(contentsOf: audioFileURL) else {
            throw APIClientError.invalidAudioFile
        }

        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.appendString("\(model)\r\n")

        if let language, !language.isEmpty {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
            body.appendString("\(language)\r\n")
        }

        if let prompt, !prompt.isEmpty {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
            body.appendString("\(prompt)\r\n")
        }

        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioFileURL.lastPathComponent)\"\r\n")
        body.appendString("Content-Type: audio/m4a\r\n\r\n")
        body.append(audioData)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")
        return body
    }

    private func decodeSuccess(responseData: Data) throws -> TranscriptionResult {
        let decoder = JSONDecoder()
        let payload = try decoder.decode(TranscribeSuccessPayload.self, from: responseData)
        let trimmed = payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw APIClientError.emptyTranscript
        }

        return TranscriptionResult(
            text: trimmed,
            durationSec: payload.durationSec,
            requestId: payload.requestId
        )
    }

    private func decodeServerError(statusCode: Int, responseData: Data) -> APIClientError {
        let decoder = JSONDecoder()
        if let payload = try? decoder.decode(TranscribeErrorPayload.self, from: responseData) {
            return .server(
                statusCode: statusCode,
                errorCode: payload.errorCode,
                message: payload.message,
                retryable: payload.retryable
            )
        }

        return .server(
            statusCode: statusCode,
            errorCode: "UNKNOWN_SERVER_ERROR",
            message: "Server returned status \(statusCode).",
            retryable: (500...599).contains(statusCode) || statusCode == 429
        )
    }
}

private struct TranscribeSuccessPayload: Decodable {
    let text: String
    let durationSec: Double?
    let requestId: String?
}

private struct TranscribeErrorPayload: Decodable {
    let errorCode: String
    let message: String
    let retryable: Bool
}

private extension Data {
    mutating func appendString(_ value: String) {
        append(Data(value.utf8))
    }
}
