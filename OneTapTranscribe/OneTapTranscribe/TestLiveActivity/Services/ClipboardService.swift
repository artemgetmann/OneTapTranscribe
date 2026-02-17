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
        UIPasteboard.general.string = text
#elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#else
        return false
#endif
        return true
    }
}
