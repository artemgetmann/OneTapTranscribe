import Foundation

#if os(iOS)
import AVFoundation
#endif

protocol RecorderServiceProtocol {
    func startRecording() async throws
    func stopRecording() async throws -> URL?
}

enum RecorderServiceError: LocalizedError {
    case permissionDenied
    case alreadyRecording
    case failedToStart
    case recordingSessionUnavailable
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required."
        case .alreadyRecording:
            return "Recording is already in progress."
        case .failedToStart:
            return "Could not start audio recording."
        case .recordingSessionUnavailable:
            return "Audio session is unavailable."
        case .unsupportedPlatform:
            return "RecorderService is only implemented on iOS."
        }
    }
}

/// AVAudioRecorder-backed recorder for MVP.
/// Keeps implementation intentionally small: single active recording and one output file.
@MainActor
final class RecorderService: RecorderServiceProtocol {
#if os(iOS)
    private let session = AVAudioSession.sharedInstance()
    private var recorder: AVAudioRecorder?
    private var activeFileURL: URL?

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    func startRecording() async throws {
        guard !isRecording else { throw RecorderServiceError.alreadyRecording }
        guard await requestRecordPermission() else {
            throw RecorderServiceError.permissionDenied
        }

        do {
            // `.measurement` reduces system processing so Whisper gets cleaner raw speech.
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw RecorderServiceError.recordingSessionUnavailable
        }

        let outputURL = try createOutputURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw RecorderServiceError.failedToStart
        }

        self.recorder = recorder
        self.activeFileURL = outputURL
    }

    func stopRecording() async throws -> URL? {
        guard let recorder else { return nil }
        recorder.stop()
        self.recorder = nil

        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Do not fail stop if audio session deactivation fails; recording file is already finalized.
        }

        let output = activeFileURL
        activeFileURL = nil
        return output
    }

    private func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            session.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func createOutputURL() throws -> URL {
        let recordingsDir = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)

        try FileManager.default.createDirectory(
            at: recordingsDir,
            withIntermediateDirectories: true
        )

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let filename = "recording-\(formatter.string(from: Date())).m4a"
            .replacingOccurrences(of: ":", with: "-")

        return recordingsDir.appendingPathComponent(filename)
    }
#else
    func startRecording() async throws {
        throw RecorderServiceError.unsupportedPlatform
    }

    func stopRecording() async throws -> URL? {
        nil
    }
#endif
}
