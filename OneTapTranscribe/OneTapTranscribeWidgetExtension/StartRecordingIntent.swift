import AppIntents
import OSLog

struct StartRecordingIntent: AudioRecordingIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Start a OneTapTranscribe recording session.")
    // Keep identifier stable so app and extension can advertise the same action identity.
    static var persistentIdentifier: String = "com.onetaptranscribe.intent.startRecording"
    // iOS 26+ expects foreground behavior to be declared via supportedModes.
    // `.foreground(.dynamic)` lets the system decide the right foreground transition.
    static var supportedModes: IntentModes = .foreground(.dynamic)
    static var isDiscoverable: Bool = false

    private let logger = Logger(subsystem: "test.OneTapTranscribe.WidgetExtension", category: "ControlIntent")

    func perform() async throws -> some IntentResult {
        let published = LiveActivityCommandStore.publishStartRequest()
        logger.info("StartRecordingIntent perform() publishedStartRequest=\(published, privacy: .public)")
        return .result()
    }
}
