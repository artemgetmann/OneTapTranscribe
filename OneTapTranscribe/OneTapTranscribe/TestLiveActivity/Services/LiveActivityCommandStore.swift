import Foundation

enum LiveActivityCommandStore {
    // Shared app-group container lets extension and app exchange lightweight commands.
    static let appGroupID = "group.test.OneTapTranscribe"

    private static let startRequestTimestampKey = "live_activity.start_request_timestamp"
    private static let stopRequestTimestampKey = "live_activity.stop_request_timestamp"

    static func latestStartRequestTimestamp() -> TimeInterval {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return 0 }
        return defaults.double(forKey: startRequestTimestampKey)
    }

    static func latestStopRequestTimestamp() -> TimeInterval {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return 0 }
        return defaults.double(forKey: stopRequestTimestampKey)
    }
}
