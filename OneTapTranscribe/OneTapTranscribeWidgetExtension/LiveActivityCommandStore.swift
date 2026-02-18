import Foundation

enum LiveActivityCommandStore {
    // Keep this identical to app target so both read/write the same shared command channel.
    static let appGroupID = "group.test.OneTapTranscribe"

    private static let stopRequestTimestampKey = "live_activity.stop_request_timestamp"

    @discardableResult
    static func publishStopRequest() -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return false }
        defaults.set(Date().timeIntervalSince1970, forKey: stopRequestTimestampKey)
        return defaults.synchronize()
    }
}
