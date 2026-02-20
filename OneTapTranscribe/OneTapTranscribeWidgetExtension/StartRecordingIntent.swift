import AppIntents
import OSLog

struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Start a OneTapTranscribe recording session.")
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    // Force a foreground launch from Control Center for reliable mic startup.
    static var supportedModes: IntentModes = .foreground(.dynamic)
    static var openAppWhenRun: Bool = true
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
