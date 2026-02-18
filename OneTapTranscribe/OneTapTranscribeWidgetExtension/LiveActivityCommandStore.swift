import Foundation
import OSLog

enum LiveActivityCommandStore {
    // Keep this identical to app target so both read/write the same shared command channel.
    static let appGroupID = "group.test.OneTapTranscribe"
    private static let logger = Logger(subsystem: "test.OneTapTranscribe.WidgetExtension", category: "CommandStore")

    private static let startRequestTimestampKey = "live_activity.start_request_timestamp"
    private static let stopRequestTimestampKey = "live_activity.stop_request_timestamp"

    @discardableResult
    static func publishStartRequest() -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return false }
        let timestamp = Date().timeIntervalSince1970
        defaults.set(timestamp, forKey: startRequestTimestampKey)
        let synced = defaults.synchronize()
        logger.info("publishStartRequest timestamp=\(timestamp, privacy: .public) synced=\(synced, privacy: .public)")
        return synced
    }

    @discardableResult
    static func publishStopRequest() -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return false }
        let timestamp = Date().timeIntervalSince1970
        defaults.set(timestamp, forKey: stopRequestTimestampKey)
        let synced = defaults.synchronize()
        logger.info("publishStopRequest timestamp=\(timestamp, privacy: .public) synced=\(synced, privacy: .public)")
        return synced
    }
}
