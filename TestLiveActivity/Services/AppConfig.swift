import Foundation

enum AppConfig {
    /// Read base URL from Info.plist first so testers can switch environments without code edits.
    /// Fallback keeps local development friction low.
    static var transcriptionBaseURL: URL {
        if
            let value = Bundle.main.object(forInfoDictionaryKey: "TRANSCRIPTION_BASE_URL") as? String,
            let url = URL(string: value)
        {
            return url
        }

        return URL(string: "http://127.0.0.1:8000")!
    }
}
