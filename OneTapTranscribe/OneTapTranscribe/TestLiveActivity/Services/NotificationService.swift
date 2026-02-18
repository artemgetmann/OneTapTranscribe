import Foundation

#if os(iOS)
import UIKit
import UserNotifications
#endif

protocol NotificationServiceProtocol {
    func requestAuthorizationIfNeeded() async
    func notifyTranscriptionResult(success: Bool, body: String, transcriptForCopy: String?) async
}

struct NotificationService: NotificationServiceProtocol {
#if os(iOS)
    fileprivate static let copyActionIdentifier = "TRANSCRIPTION_COPY_ACTION"
    fileprivate static let resultCategoryIdentifier = "TRANSCRIPTION_RESULT_CATEGORY"
    fileprivate static let cachedTranscriptDefaultsKey = "notification.cached_transcript"
    fileprivate static let delegate = NotificationCenterDelegate()

    private let center = UNUserNotificationCenter.current()

    static func installNotificationDelegate() {
        // UNUserNotificationCenter keeps a weak delegate; retain it statically.
        UNUserNotificationCenter.current().delegate = delegate
    }

    private func registerCategories() {
        let copyAction = UNNotificationAction(
            identifier: Self.copyActionIdentifier,
            title: "Copy transcript",
            options: []
        )
        let resultCategory = UNNotificationCategory(
            identifier: Self.resultCategoryIdentifier,
            actions: [copyAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([resultCategory])
    }

    private static func cacheTranscriptForCopyAction(_ transcript: String?) {
        guard let defaults = UserDefaults(suiteName: LiveActivityCommandStore.appGroupID) else { return }
        guard let transcript else {
            defaults.removeObject(forKey: cachedTranscriptDefaultsKey)
            return
        }
        defaults.set(transcript, forKey: cachedTranscriptDefaultsKey)
    }

    fileprivate static func loadCachedTranscript() -> String? {
        guard let defaults = UserDefaults(suiteName: LiveActivityCommandStore.appGroupID) else { return nil }
        return defaults.string(forKey: cachedTranscriptDefaultsKey)
    }
#endif

    func requestAuthorizationIfNeeded() async {
#if os(iOS)
        registerCategories()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
#endif
    }

    func notifyTranscriptionResult(success: Bool, body: String, transcriptForCopy: String?) async {
#if os(iOS)
        if success, let transcriptForCopy, !transcriptForCopy.isEmpty {
            Self.cacheTranscriptForCopyAction(transcriptForCopy)
        } else {
            Self.cacheTranscriptForCopyAction(nil)
        }

        let content = UNMutableNotificationContent()
        content.title = success ? "Transcription complete" : "Transcription failed"
        content.body = body
        content.sound = .default
        if success, transcriptForCopy != nil {
            content.categoryIdentifier = Self.resultCategoryIdentifier
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
#else
        _ = success
        _ = body
        _ = transcriptForCopy
#endif
    }
}

#if os(iOS)
private final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard response.actionIdentifier == NotificationService.copyActionIdentifier else {
            completionHandler()
            return
        }

        let transcript = NotificationService.loadCachedTranscript() ?? ""
        let copied = Task { @MainActor in
            ClipboardService().copy(transcript)
        }

        Task {
            let didCopy = await copied.value
            let feedback = UNMutableNotificationContent()
            feedback.title = didCopy ? "Copied" : "Copy failed"
            feedback.body = didCopy
                ? "Transcript copied to clipboard."
                : "Couldn't copy in background. Open app and tap Copy."
            feedback.sound = .default
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: feedback,
                trigger: nil
            )
            try? await center.add(request)
            completionHandler()
        }
    }
}
#endif
