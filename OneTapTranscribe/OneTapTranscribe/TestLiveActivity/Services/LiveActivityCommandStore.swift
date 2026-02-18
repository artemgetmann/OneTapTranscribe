import Foundation

enum LiveActivityCommandStore {
    // Shared app-group container lets extension and app exchange lightweight commands.
    static let appGroupID = "group.test.OneTapTranscribe"

    private static let stopRequestTimestampKey = "live_activity.stop_request_timestamp"

    static func latestStopRequestTimestamp() -> TimeInterval {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return 0 }
        return defaults.double(forKey: stopRequestTimestampKey)
    }
}
