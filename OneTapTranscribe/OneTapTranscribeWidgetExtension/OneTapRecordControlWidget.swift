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
            .tint(Color(red: 0.545, green: 0.361, blue: 0.965))
        }
        .displayName("OneTap Record")
        .description("Start recording from Control Center and immediately show recording state.")
    }
}
