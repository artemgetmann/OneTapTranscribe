import AppIntents

struct StartRecordingIntent: AudioRecordingIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Start a OneTapTranscribe recording session.")
    static var openAppWhenRun: Bool = false
    static var supportedModes: IntentModes = .background
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        _ = LiveActivityCommandStore.publishStartRequest()
        return .result()
    }
}
