import AppIntents

struct StartRecordingIntent: AudioRecordingIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Start a OneTapTranscribe recording session.")
    static var persistentIdentifier: String = "com.onetaptranscribe.intent.startRecording"
    static var supportedModes: IntentModes = .foreground(.immediate)
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult & OpensIntent {
        _ = LiveActivityCommandStore.publishStartRequest()
        return .result(
            opensIntent: OpenURLIntent(
                URL(string: "onetaptranscribe://start")!
            )
        )
    }
}
