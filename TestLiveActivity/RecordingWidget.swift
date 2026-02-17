#if os(iOS)
import ActivityKit
import SwiftUI
import WidgetKit

/// Widget extension for Live Activity
struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
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
                    Text("Recording...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Button(intent: StopRecordingIntent()) {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(.red)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            } compactLeading: {
                // Compact leading (left side of pill)
                HStack(spacing: 4) {
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                    Text("REC")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
            } compactTrailing: {
                // Compact trailing (right side of pill)
                Text(formatTime(context.state.elapsedSeconds))
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
            } minimal: {
                // Minimal (when sharing Dynamic Island)
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
            }
        }
    }

    func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

/// Lock screen banner view
struct LockScreenView: View {
    let context: ActivityViewContext<RecordingAttributes>

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
                Text("Recording")
                    .fontWeight(.semibold)
            }

            Spacer()

            Text(formatTime(context.state.elapsedSeconds))
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.bold)

            Spacer()

            Button(intent: StopRecordingIntent()) {
                Image(systemName: "stop.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.red)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

/// Intent for Stop button in Live Activity
import AppIntents

struct StopRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Recording"
    static var description = IntentDescription("Stops the current recording")

    func perform() async throws -> some IntentResult {
        // This will be handled by the main app
        // For now, just return success
        return .result()
    }
}
#endif
