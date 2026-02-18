import SwiftUI

@main
struct TestLiveActivityApp: App {
    @StateObject private var stateStore: RecordingStateStore

    init() {
        let liveActivityService = LiveActivityService()
        let recorderService = RecorderService()
        let apiClient = APIClient()
        let transcriptionQueue = TranscriptionQueue(apiClient: apiClient)
        let clipboardService = ClipboardService()

        // Centralized composition root for this MVP spike.
        _stateStore = StateObject(
            wrappedValue: RecordingStateStore(
                liveActivityService: liveActivityService,
                recorderService: recorderService,
                transcriptionQueue: transcriptionQueue,
                clipboardService: clipboardService
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(stateStore: stateStore)
                .onOpenURL { url in
                    guard url.scheme == "onetaptranscribe" else { return }

                    // Live Activity stop controls deep-link into app.
                    if url.host == "stop" || url.path == "/stop" {
                        Task { await stateStore.stopRecording() }
                    }
                }
        }
    }
}
