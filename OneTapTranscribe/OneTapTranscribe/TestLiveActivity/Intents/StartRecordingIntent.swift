import AppIntents
import OSLog

// Workaround for iOS Control Center openAppWhenRun inconsistencies:
// keep a matching control intent type in the app target as well as the widget extension target.
struct ControlCenterStartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Start a OneTapTranscribe recording session.")
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    // Force a foreground launch when this control intent executes.
    static var supportedModes: IntentModes = .foreground(.dynamic)
    static var openAppWhenRun: Bool = true
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
