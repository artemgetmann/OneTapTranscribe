import AppIntents
import OSLog

struct StartRecordingIntent: AudioRecordingIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Start a OneTapTranscribe recording session.")
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    // Keep background mode declared for compatibility with control surfaces.
    static var supportedModes: IntentModes = .background
    // Real devices reject AVAudioRecorder startup from cold/background launches.
    // For reliability, force foreground transition before consuming the start command.
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
