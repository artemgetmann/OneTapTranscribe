import Foundation

enum AppConfigError: LocalizedError {
    case invalidBaseURL

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Enter a valid http:// or https:// backend URL."
        }
    }
}

enum AppConfig {
    private static let baseURLDefaultsKey = "transcription_base_url"
    private static let clientTokenDefaultsKey = "transcription_client_token"

    /// Read base URL from Info.plist first so testers can switch environments without code edits.
    /// Fallback keeps local development friction low.
    static var transcriptionBaseURL: URL {
        if
            let stored = UserDefaults.standard.string(forKey: baseURLDefaultsKey),
            let url = URL(string: stored),
            isSupportedBaseURL(url)
        {
            return url
        }

        if
            let value = Bundle.main.object(forInfoDictionaryKey: "TRANSCRIPTION_BASE_URL") as? String,
            let url = URL(string: value),
            isSupportedBaseURL(url)
        {
            return url
        }

        return URL(string: "http://127.0.0.1:8000")!
    }

    static var transcriptionBaseURLString: String {
        transcriptionBaseURL.absoluteString
    }

    static var clientToken: String? {
        if let stored = UserDefaults.standard.string(forKey: clientTokenDefaultsKey) {
            let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let bundled = Bundle.main.object(forInfoDictionaryKey: "TRANSCRIPTION_CLIENT_TOKEN") as? String {
            let trimmed = bundled.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return nil
    }

    static func setTranscriptionBaseURL(_ rawValue: String) throws {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmed),
            isSupportedBaseURL(url)
        else {
            throw AppConfigError.invalidBaseURL
        }

        // Persist string form so users can point to hosted backend without rebuilding app.
        UserDefaults.standard.set(url.absoluteString, forKey: baseURLDefaultsKey)
    }

    static func clearTranscriptionBaseURLOverride() {
        UserDefaults.standard.removeObject(forKey: baseURLDefaultsKey)
    }

    static func setClientToken(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: clientTokenDefaultsKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: clientTokenDefaultsKey)
        }
    }

    private static func isSupportedBaseURL(_ url: URL) -> Bool {
        guard
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            return false
        }
        return url.host != nil || url.absoluteString.hasPrefix("http://127.0.0.1")
    }
}
