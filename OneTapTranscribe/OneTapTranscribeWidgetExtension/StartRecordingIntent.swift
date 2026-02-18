import AppIntents

struct StartRecordingIntent: AudioRecordingIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Start a OneTapTranscribe recording session.")
    // Reliable start requires app process to become active on real devices.
    // Without foregrounding, the command may sit until user opens the app manually.
    static var openAppWhenRun: Bool = true
    static var supportedModes: IntentModes = .foreground
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        _ = LiveActivityCommandStore.publishStartRequest()
        return .result()
    }
}
