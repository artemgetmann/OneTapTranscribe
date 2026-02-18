import Foundation

#if os(iOS)
import UserNotifications
#endif

protocol NotificationServiceProtocol {
    func requestAuthorizationIfNeeded() async
    func notifyTranscriptionResult(success: Bool, body: String) async
}

struct NotificationService: NotificationServiceProtocol {
#if os(iOS)
    private let center = UNUserNotificationCenter.current()
#endif

    func requestAuthorizationIfNeeded() async {
#if os(iOS)
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
#endif
    }

    func notifyTranscriptionResult(success: Bool, body: String) async {
#if os(iOS)
        let content = UNMutableNotificationContent()
        content.title = success ? "Transcription complete" : "Transcription failed"
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
#else
        _ = success
        _ = body
#endif
    }
}
