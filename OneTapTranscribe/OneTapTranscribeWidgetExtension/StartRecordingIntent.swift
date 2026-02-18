import AppIntents
import OSLog

struct StartRecordingIntent: AudioRecordingIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Start a OneTapTranscribe recording session.")
    // Keep identifier stable so app and extension can advertise the same action identity.
    static var persistentIdentifier: String = "com.onetaptranscribe.intent.startRecording"
    // Control Center start must foreground the app so AVAudioSession + recorder startup is reliable.
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = false

    private let logger = Logger(subsystem: "test.OneTapTranscribe.WidgetExtension", category: "ControlIntent")

    func perform() async throws -> some IntentResult {
        let published = LiveActivityCommandStore.publishStartRequest()
        logger.info("StartRecordingIntent perform() publishedStartRequest=\(published, privacy: .public)")
        return .result()
    }
}
