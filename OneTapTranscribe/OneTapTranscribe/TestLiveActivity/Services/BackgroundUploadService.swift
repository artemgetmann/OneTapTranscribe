import Foundation

#if os(iOS)
import UIKit

/// Background URLSession transport for uploads that must outlive foreground app execution.
final class BackgroundUploadService: NSObject {
    static let shared = BackgroundUploadService()
    static let sessionIdentifier = "test.OneTapTranscribe.background-upload"

    private enum NetworkTuning {
        static let requestTimeoutSeconds: TimeInterval = 25
        static let resourceTimeoutSeconds: TimeInterval = 180
    }

    private struct PendingTask {
        var responseData = Data()
        let bodyFileURL: URL
        let continuation: CheckedContinuation<(Data, URLResponse), Error>
    }

    private let lock = NSLock()
    private var pendingTasks: [Int: PendingTask] = [:]
    private var backgroundCompletionHandler: (() -> Void)?

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        configuration.isDiscretionary = false
        // Fail and retry from our queue instead of waiting indefinitely for connectivity.
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = NetworkTuning.requestTimeoutSeconds
        configuration.timeoutIntervalForResource = NetworkTuning.resourceTimeoutSeconds
        configuration.sessionSendsLaunchEvents = true
        return URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )
    }()

    private override init() {
        super.init()
    }

    func upload(request: URLRequest, bodyFileURL: URL) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = session.uploadTask(with: request, fromFile: bodyFileURL)
            lock.lock()
            pendingTasks[task.taskIdentifier] = PendingTask(
                bodyFileURL: bodyFileURL,
                continuation: continuation
            )
            lock.unlock()
            task.resume()
        }
    }

    func setBackgroundCompletionHandler(_ completionHandler: @escaping () -> Void) {
        lock.lock()
        backgroundCompletionHandler = completionHandler
        lock.unlock()
    }
}

extension BackgroundUploadService: URLSessionDataDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard var pending = pendingTasks[dataTask.taskIdentifier] else {
            lock.unlock()
            return
        }
        pending.responseData.append(data)
        pendingTasks[dataTask.taskIdentifier] = pending
        lock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let pending = pendingTasks.removeValue(forKey: task.taskIdentifier)
        lock.unlock()

        guard let pending else { return }

        try? FileManager.default.removeItem(at: pending.bodyFileURL)

        if let error {
            pending.continuation.resume(throwing: error)
            return
        }

        guard let response = task.response else {
            pending.continuation.resume(throwing: URLError(.badServerResponse))
            return
        }

        pending.continuation.resume(returning: (pending.responseData, response))
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        lock.lock()
        let completionHandler = backgroundCompletionHandler
        backgroundCompletionHandler = nil
        lock.unlock()
        completionHandler?()
    }
}
#endif
