import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Thin wrapper over system pasteboard so UI/store code stays testable.
struct ClipboardService {
    @discardableResult
    func copy(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }

#if canImport(UIKit)
        let pasteboard = UIPasteboard.general
        pasteboard.string = text

        // iOS can reject/obscure pasteboard reads when the app is backgrounded.
        // In background we treat assignment as best-effort and rely on the app-open fallback path.
        if UIApplication.shared.applicationState != .active {
            return true
        }

        // Foreground read-back catches obvious failures when app is active.
        return pasteboard.string == text
#elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        let wrote = NSPasteboard.general.setString(text, forType: .string)
        return wrote
#else
        return false
#endif
    }
}
