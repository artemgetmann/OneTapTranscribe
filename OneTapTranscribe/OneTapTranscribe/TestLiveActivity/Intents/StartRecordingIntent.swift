import AppIntents
import OSLog

struct StartRecordingIntent: AudioRecordingIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Start a OneTapTranscribe recording session.")
    static var persistentIdentifier: String = "com.onetaptranscribe.intent.startRecording"
    // Keep app-side declaration aligned with extension-side mode semantics.
    static var supportedModes: IntentModes = .foreground(.dynamic)
    static var isDiscoverable: Bool = false

    private let logger = Logger(subsystem: "test.OneTapTranscribe", category: "ControlIntent")

    func perform() async throws -> some IntentResult {
        let published = LiveActivityCommandStore.publishStartRequest()
        logger.info("App StartRecordingIntent perform() publishedStartRequest=\(published, privacy: .public)")
        return .result()
    }
}
