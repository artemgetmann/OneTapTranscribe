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
    static let copyActionIdentifier = "TRANSCRIPTION_COPY_ACTION"
    static let resultCategoryIdentifier = "TRANSCRIPTION_RESULT_CATEGORY"
    static let cachedTranscriptDefaultsKey = "notification.cached_transcript"
    fileprivate static let delegate = NotificationCenterDelegate()

    private let center = UNUserNotificationCenter.current()

    private static var transcriptDefaults: UserDefaults {
        // Use app group when available so app/widget/intent surfaces share a single source of truth.
        UserDefaults(suiteName: LiveActivityCommandStore.appGroupID) ?? .standard
    }

    static func installNotificationDelegate() {
        // UNUserNotificationCenter keeps a weak delegate; retain it statically.
        UNUserNotificationCenter.current().delegate = delegate
    }

    private func registerCategories() {
        let copyAction = UNNotificationAction(
            identifier: Self.copyActionIdentifier,
            title: "Copy transcript",
            // Foreground action gives us a reliable lifecycle transition where pasteboard writes succeed.
            options: [.foreground]
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
        let defaults = transcriptDefaults
        guard let transcript else {
            defaults.removeObject(forKey: cachedTranscriptDefaultsKey)
            return
        }
        defaults.set(transcript, forKey: cachedTranscriptDefaultsKey)
    }

    static func loadCachedTranscript() -> String? {
        let defaults = transcriptDefaults
        return defaults.string(forKey: cachedTranscriptDefaultsKey)
    }

    static func clearCachedTranscript() {
        transcriptDefaults.removeObject(forKey: cachedTranscriptDefaultsKey)
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
    private enum CopyFeedback {
        case copied
        case queuedForForeground
    }

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
        guard !transcript.isEmpty else {
            Task {
                let feedback = UNMutableNotificationContent()
                feedback.title = "Copy failed"
                feedback.body = "No transcript found to copy."
                feedback.sound = .default
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: feedback,
                    trigger: nil
                )
                try? await center.add(request)
                completionHandler()
            }
            return
        }

        // Persist first so copy can complete after app enters foreground.
        DeferredClipboardStore.save(transcript)

        let copyFeedback = Task { @MainActor in
            let copied = ClipboardService().copy(transcript)
            if copied {
                DeferredClipboardStore.clear()
                NotificationService.clearCachedTranscript()
                return CopyFeedback.copied
            }
            return CopyFeedback.queuedForForeground
        }

        Task {
            let feedbackResult = await copyFeedback.value
            let feedback = UNMutableNotificationContent()
            switch feedbackResult {
            case .copied:
                feedback.title = "Copied"
                feedback.body = "Transcript copied to clipboard."
            case .queuedForForeground:
                feedback.title = "Copy queued"
                feedback.body = "Opening app to finish clipboard copy."
            }
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
