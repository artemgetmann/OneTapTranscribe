import SwiftUI
import WidgetKit

@main
struct OneTapTranscribeWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        RecordingLiveActivityWidget()
        if #available(iOS 18.0, *) {
            OneTapRecordControlWidget()
        }
    }
}
