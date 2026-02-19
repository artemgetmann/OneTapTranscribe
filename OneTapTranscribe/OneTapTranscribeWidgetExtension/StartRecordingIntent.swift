import AppIntents
import OSLog

struct StartRecordingIntent: AudioRecordingIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Start a OneTapTranscribe recording session.")
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    // R&D spike: allow background execution path and let system decide if it can keep app hidden.
    static var supportedModes: IntentModes = .background
    static var isDiscoverable: Bool = true

    private let logger = Logger(subsystem: "test.OneTapTranscribe.WidgetExtension", category: "ControlIntent")

    func perform() async throws -> some IntentResult {
        let published = LiveActivityCommandStore.publishStartRequest()
        logger.info("StartRecordingIntent perform() publishedStartRequest=\(published, privacy: .public)")
        if !published {
            logger.error("StartRecordingIntent failed to publish start request to app-group defaults")
        }
        return .result()
    }
}
