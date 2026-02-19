import AppIntents
import OSLog

struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Start a OneTapTranscribe recording session.")
    // Keep app-target intent behavior aligned with extension intent.
    static var openAppWhenRun: Bool = true
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static var supportedModes: IntentModes = .foreground(.dynamic)
    static var isDiscoverable: Bool = true

    private let logger = Logger(subsystem: "test.OneTapTranscribe", category: "ControlIntent")

    func perform() async throws -> some IntentResult {
        let published = LiveActivityCommandStore.publishStartRequest()
        logger.info("App StartRecordingIntent perform() publishedStartRequest=\(published, privacy: .public)")
        if !published {
            logger.error("App StartRecordingIntent failed to publish start request to app-group defaults")
        }
        return .result()
    }
}
