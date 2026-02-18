import SwiftUI

@main
struct TestLiveActivityApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var stateStore: RecordingStateStore
#if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
#endif

    init() {
#if os(iOS)
        NotificationService.installNotificationDelegate()
#endif
        let liveActivityService = LiveActivityService()
        let recorderService = RecorderService()
        let apiClient = APIClient()
        let transcriptionQueue = TranscriptionQueue(apiClient: apiClient)
        let clipboardService = ClipboardService()
        let notificationService = NotificationService()
        let backgroundTaskService = BackgroundTaskService()

        // Centralized composition root for this MVP spike.
        _stateStore = StateObject(
            wrappedValue: RecordingStateStore(
                liveActivityService: liveActivityService,
                recorderService: recorderService,
                transcriptionQueue: transcriptionQueue,
                clipboardService: clipboardService,
                notificationService: notificationService,
                backgroundTaskService: backgroundTaskService
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(stateStore: stateStore)
                .task {
                    await stateStore.prepareNotifications()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    stateStore.handleAppDidBecomeActive()
                }
                .onOpenURL { url in
                    guard url.scheme == "onetaptranscribe" else { return }

                    // Start/stop controls deep-link into app for deterministic routing.
                    if url.host == "start" || url.path == "/start" {
                        Task { await stateStore.startRecording() }
                        return
                    }

                    if url.host == "stop" || url.path == "/stop" {
                        Task { await stateStore.stopRecording() }
                    }
                }
        }
    }
}
