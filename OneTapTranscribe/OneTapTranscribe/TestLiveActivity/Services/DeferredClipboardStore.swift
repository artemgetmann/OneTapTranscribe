import Foundation

/// Persists a pending clipboard payload across background/suspend/relaunch boundaries.
/// This makes notification-driven copy actions recoverable even when iOS defers pasteboard access.
enum DeferredClipboardStore {
    private static let pendingClipboardTextKey = "clipboard.pending_text"
    private static let appGroupID = LiveActivityCommandStore.appGroupID

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func save(_ text: String?) {
        guard let text, !text.isEmpty else {
            defaults.removeObject(forKey: pendingClipboardTextKey)
            return
        }
        defaults.set(text, forKey: pendingClipboardTextKey)
    }

    static func load() -> String? {
        defaults.string(forKey: pendingClipboardTextKey)
    }

    static func clear() {
        defaults.removeObject(forKey: pendingClipboardTextKey)
    }
}
