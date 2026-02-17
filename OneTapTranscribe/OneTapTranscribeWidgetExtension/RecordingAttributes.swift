import ActivityKit
import Foundation

/// Live Activity payload contract shared by the host app and widget extension.
/// Keep this in sync with the app-side `RecordingAttributes` shape.
struct RecordingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var isUploading: Bool
    }

    var startTime: Date
}
