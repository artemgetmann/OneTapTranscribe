import Foundation

#if os(iOS)
import ActivityKit

/// Shared between main app and widget extension.
struct RecordingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var isUploading: Bool
    }

    // Static properties (do not change during activity lifetime).
    var startTime: Date
}
#else
/// Non-iOS fallback so shared files can still typecheck in local CLI environments.
struct RecordingAttributes {
    struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var isUploading: Bool
    }

    var startTime: Date
}
#endif
