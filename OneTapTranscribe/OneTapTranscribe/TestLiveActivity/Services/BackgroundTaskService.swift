import Foundation

#if canImport(UIKit)
import UIKit
#endif

struct BackgroundTaskToken {
    fileprivate let endClosure: () -> Void

    func end() {
        endClosure()
    }
}

protocol BackgroundTaskServiceProtocol {
    func beginTask(named name: String) -> BackgroundTaskToken
    func endTask(_ token: BackgroundTaskToken)
}

@MainActor
struct BackgroundTaskService: BackgroundTaskServiceProtocol {
    func beginTask(named name: String) -> BackgroundTaskToken {
#if canImport(UIKit)
        var taskIdentifier: UIBackgroundTaskIdentifier = .invalid
        taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: name) {
            // Expiration handler is intentionally lightweight; store-level retries handle failures.
            if taskIdentifier != .invalid {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
                taskIdentifier = .invalid
            }
        }

        return BackgroundTaskToken {
            if taskIdentifier != .invalid {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
                taskIdentifier = .invalid
            }
        }
#else
        _ = name
        return BackgroundTaskToken(endClosure: {})
#endif
    }

    func endTask(_ token: BackgroundTaskToken) {
        token.end()
    }
}
