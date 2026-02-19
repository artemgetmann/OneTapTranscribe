import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

private let brandAccent = Color(red: 0.604, green: 0.424, blue: 0.973)
private let brandBlue = Color(red: 0.400, green: 0.494, blue: 0.976)
private let brandViolet = Color(red: 0.769, green: 0.357, blue: 0.988)
private let brandGradient = LinearGradient(
    colors: [Color(red: 0.400, green: 0.494, blue: 0.976), Color(red: 0.769, green: 0.357, blue: 0.988)],
    startPoint: .leading,
    endPoint: .trailing
)

struct RecordingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingAttributes.self) { context in
            LockScreenRecordingView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(brandGradient)
                            .frame(width: 8, height: 8)
                        Image(systemName: "waveform")
                            .font(.caption2.weight(.semibold))
                    }
                    .padding(.leading, 8)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: StopRecordingIntent()) {
                        ZStack {
                            Circle()
                                .fill(brandGradient)
                                .frame(width: 30, height: 30)

                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(.white)
                                .frame(width: 9, height: 9)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop recording")
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.isUploading ? "Uploading..." : "Recording...")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(formatTime(context.state.elapsedSeconds))
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.semibold)
                    }
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(brandGradient)
                        .frame(width: 6, height: 6)
                    Image(systemName: "waveform")
                        .font(.caption2.weight(.semibold))
                }
                .padding(.leading, 4)
            } compactTrailing: {
                HStack(spacing: 6) {
                    Text(formatTime(context.state.elapsedSeconds))
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)

                    Button(intent: StopRecordingIntent()) {
                        ZStack {
                            Circle()
                                .fill(brandGradient)
                                .frame(width: 20, height: 20)

                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .fill(.white)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop recording")
                }
            } minimal: {
                Circle()
                    .fill(brandGradient)
                    .frame(width: 10, height: 10)
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

private struct LockScreenRecordingView: View {
    let context: ActivityViewContext<RecordingAttributes>

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(brandGradient)
                        .frame(width: 10, height: 10)
                    Text(context.state.isUploading ? "Uploading" : "Recording")
                        .fontWeight(.semibold)
                }

                Spacer()

                Text(formatTime(context.state.elapsedSeconds))
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.bold)
            }

            HStack(spacing: 10) {
                LiveWaveformView(isActive: !context.state.isUploading)
                    .frame(height: 18)

                Spacer(minLength: 0)

                Button(intent: StopRecordingIntent()) {
                    Label("Stop", systemImage: "stop.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(brandGradient))
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

private struct LiveWaveformView: View {
    let isActive: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            HStack(spacing: 3) {
                ForEach(0..<11, id: \.self) { idx in
                    let phase = t * 4 + Double(idx) * 0.45
                    let base = isActive ? 7.0 : 4.0
                    let amplitude = isActive ? 8.0 : 1.0
                    let height = base + (sin(phase) + 1.0) * 0.5 * amplitude

                    let barFill: LinearGradient = isActive
                        ? brandGradient
                        : LinearGradient(colors: [Color.secondary.opacity(0.4)], startPoint: .leading, endPoint: .trailing)

                    Capsule(style: .continuous)
                        .fill(barFill)
                        .frame(width: 3, height: height)
                }
            }
        }
    }
}
