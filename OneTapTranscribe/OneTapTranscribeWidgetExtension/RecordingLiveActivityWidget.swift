import ActivityKit
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
        .padding(.horizontal)
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
