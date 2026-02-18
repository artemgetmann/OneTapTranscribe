import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct OneTapRecordControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "test.OneTapTranscribe.control.startRecording") {
            ControlWidgetButton(action: StartRecordingIntent()) {
                Label("Start Recording", systemImage: "waveform.circle.fill")
            }
            .tint(.red)
        }
        .displayName("OneTap Record")
        .description("Start recording from Control Center without opening the app.")
    }
}
