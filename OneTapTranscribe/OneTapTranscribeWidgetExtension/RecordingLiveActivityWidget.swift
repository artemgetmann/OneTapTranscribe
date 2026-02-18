import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct RecordingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingAttributes.self) { context in
            LockScreenRecordingView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("REC")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatTime(context.state.elapsedSeconds))
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.isUploading ? "Uploading..." : "Recording...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        LiveWaveformView(isActive: !context.state.isUploading)
                            .frame(width: 78, height: 18)

                        Spacer(minLength: 0)

                        Button(intent: StopRecordingIntent()) {
                            Label("Stop", systemImage: "stop.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(.red))
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                    Text("REC")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
            } compactTrailing: {
                Text(formatTime(context.state.elapsedSeconds))
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
            } minimal: {
                Circle()
                    .fill(.red)
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
                        .fill(.red)
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
                        .background(Capsule().fill(.red))
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

                    Capsule(style: .continuous)
                        .fill(isActive ? Color.red.opacity(0.9) : Color.secondary.opacity(0.4))
                        .frame(width: 3, height: height)
                }
            }
        }
    }
}
