import Foundation
import OSLog

enum LiveActivityCommandStore {
    // Shared app-group container lets extension and app exchange lightweight commands.
    static let appGroupID = "group.test.OneTapTranscribe"
    private static let logger = Logger(subsystem: "test.OneTapTranscribe", category: "CommandStore")

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
        let timestamp = Date().timeIntervalSince1970
        defaults.set(timestamp, forKey: startRequestTimestampKey)
        let synced = defaults.synchronize()
        logger.info("publishStartRequest timestamp=\(timestamp, privacy: .public) synced=\(synced, privacy: .public)")
        return synced
    }

    @discardableResult
    static func publishStopRequest() -> Bool {
        guard let defaults else { return false }
        let timestamp = Date().timeIntervalSince1970
        defaults.set(timestamp, forKey: stopRequestTimestampKey)
        let synced = defaults.synchronize()
        logger.info("publishStopRequest timestamp=\(timestamp, privacy: .public) synced=\(synced, privacy: .public)")
        return synced
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
        logger.info("markStartRequestConsumed timestamp=\(timestamp, privacy: .public)")
    }

    static func markStopRequestConsumed(_ timestamp: TimeInterval) {
        guard let defaults else { return }
        defaults.set(timestamp, forKey: consumedStopRequestTimestampKey)
        logger.info("markStopRequestConsumed timestamp=\(timestamp, privacy: .public)")
    }
}
