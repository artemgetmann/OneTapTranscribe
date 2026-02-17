import Foundation

#if os(iOS)
import ActivityKit
#endif

@MainActor
final class LiveActivityService {
#if os(iOS)
    private var activity: Activity<RecordingAttributes>?
#endif

    var hasActiveActivity: Bool {
#if os(iOS)
        activity != nil
#else
        false
#endif
    }

    func canStartActivities() -> Bool {
#if os(iOS)
        ActivityAuthorizationInfo().areActivitiesEnabled
#else
        false
#endif
    }

    /// Creates a single live activity for the active recording session.
    /// Callers own retry/rollback behavior if request fails.
    func startLiveActivity(startTime: Date) throws {
#if os(iOS)
        let attributes = RecordingAttributes(startTime: startTime)
        let initialState = RecordingAttributes.ContentState(
            elapsedSeconds: 0,
            isUploading: false
        )

        activity = try Activity.request(
            attributes: attributes,
            content: .init(state: initialState, staleDate: nil),
            pushType: nil
        )
#else
        _ = startTime
#endif
    }

    /// Pushes incremental state updates to the currently active Live Activity.
    func updateLiveActivity(elapsedSeconds: Int, isUploading: Bool) async {
#if os(iOS)
        guard let activity else { return }

        let state = RecordingAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            isUploading: isUploading
        )

        await activity.update(ActivityContent(state: state, staleDate: nil))
#else
        _ = elapsedSeconds
        _ = isUploading
#endif
    }

    /// Ends and clears any active Live Activity immediately.
    func stopLiveActivity() async {
#if os(iOS)
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
#endif
    }
}
