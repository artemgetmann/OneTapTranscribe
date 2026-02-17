import SwiftUI

struct ContentView: View {
    @ObservedObject var stateStore: RecordingStateStore

    var body: some View {
        VStack(spacing: 30) {
            Text("OneTapTranscribe MVP")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(stateStore.statusMessage)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if stateStore.isRecording {
                Text("\(stateStore.elapsedSeconds)s")
                    .font(.system(size: 60, weight: .bold, design: .monospaced))
            }

            HStack(spacing: 20) {
                Button {
                    // View only dispatches intents; store owns side effects.
                    Task { await stateStore.startRecording() }
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(stateStore.isRecording ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(stateStore.isRecording || stateStore.isUploading)

                Button {
                    // Keep stop async so UI stays responsive during shutdown/transcription handoff.
                    Task { await stateStore.stopRecording() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(stateStore.isRecording ? Color.red : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!stateStore.isRecording)
            }
            .padding(.horizontal)

            if stateStore.isUploading {
                ProgressView("Uploading / transcribing...")
                    .progressViewStyle(.circular)
            }

            if let lastTranscript = stateStore.lastTranscript {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Latest transcript")
                        .font(.headline)
                    Text(lastTranscript)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(4)

                    Button("Copy transcript again") {
                        stateStore.copyLastTranscriptToClipboard()
                    }
                    .font(.footnote)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Test Instructions:")
                    .font(.headline)
                Text("1. Tap Start")
                Text("2. Go to Home screen")
                Text("3. Open Safari or another app")
                Text("4. Check: Is Live Activity visible?")
                Text("   - iPhone 14+: Dynamic Island")
                Text("   - iPad/older: Lock screen only?")
            }
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding()
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 50)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(stateStore: .preview)
    }
}
