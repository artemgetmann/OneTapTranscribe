import Foundation

enum LiveActivityCommandStore {
    // Shared app-group container lets extension and app exchange lightweight commands.
    static let appGroupID = "group.test.OneTapTranscribe"

    private static let startRequestTimestampKey = "live_activity.start_request_timestamp"
    private static let stopRequestTimestampKey = "live_activity.stop_request_timestamp"
    private static let consumedStartRequestTimestampKey = "live_activity.start_request_consumed_timestamp"
    private static let consumedStopRequestTimestampKey = "live_activity.stop_request_consumed_timestamp"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    @discardableResult
    static func publishStartRequest() -> Bool {
        guard let defaults else { return false }
        defaults.set(Date().timeIntervalSince1970, forKey: startRequestTimestampKey)
        return defaults.synchronize()
    }

    @discardableResult
    static func publishStopRequest() -> Bool {
        guard let defaults else { return false }
        defaults.set(Date().timeIntervalSince1970, forKey: stopRequestTimestampKey)
        return defaults.synchronize()
    }

    static func latestStartRequestTimestamp() -> TimeInterval {
        guard let defaults else { return 0 }
        return defaults.double(forKey: startRequestTimestampKey)
    }

    static func latestStopRequestTimestamp() -> TimeInterval {
        guard let defaults else { return 0 }
        return defaults.double(forKey: stopRequestTimestampKey)
    }

    static func latestConsumedStartRequestTimestamp() -> TimeInterval {
        guard let defaults else { return 0 }
        return defaults.double(forKey: consumedStartRequestTimestampKey)
    }

    static func latestConsumedStopRequestTimestamp() -> TimeInterval {
        guard let defaults else { return 0 }
        return defaults.double(forKey: consumedStopRequestTimestampKey)
    }

    static func markStartRequestConsumed(_ timestamp: TimeInterval) {
        guard let defaults else { return }
        defaults.set(timestamp, forKey: consumedStartRequestTimestampKey)
    }

    static func markStopRequestConsumed(_ timestamp: TimeInterval) {
        guard let defaults else { return }
        defaults.set(timestamp, forKey: consumedStopRequestTimestampKey)
    }
}
