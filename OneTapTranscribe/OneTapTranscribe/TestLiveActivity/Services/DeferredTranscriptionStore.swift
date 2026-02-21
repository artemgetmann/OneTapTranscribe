import Foundation

/// Persists pending transcription audio files so failures never drop user recordings.
/// Data is shared via app group to survive suspend/relaunch boundaries.
enum DeferredTranscriptionStore {
    private static let pendingAudioPathsKey = "transcription.pending_audio_paths"
    private static let appGroupID = LiveActivityCommandStore.appGroupID

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func load() -> [URL] {
        let rawPaths = defaults.array(forKey: pendingAudioPathsKey) as? [String] ?? []
        let existing = rawPaths
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }

        // Clean stale entries eagerly so we do not keep retrying missing files.
        save(existing)
        return existing
    }

    static func save(_ fileURLs: [URL]) {
        let uniquePaths = Array(
            Set(fileURLs.map(\.path))
        ).sorted()
        defaults.set(uniquePaths, forKey: pendingAudioPathsKey)
    }
}
