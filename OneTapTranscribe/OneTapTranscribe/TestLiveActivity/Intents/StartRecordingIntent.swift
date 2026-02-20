import AppIntents
import OSLog

struct AppStartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "App Start Recording"
    static var description = IntentDescription("Start a OneTapTranscribe recording session.")
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    // Keep app-local intent foreground-capable, but hide it from user-facing discovery
    // so Control Center binds to the widget-extension intent path instead.
    static var supportedModes: IntentModes = .foreground(.dynamic)
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = false

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
