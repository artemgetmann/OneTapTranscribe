import SwiftUI

struct ContentView: View {
    @ObservedObject var stateStore: RecordingStateStore
    @Environment(\.colorScheme) private var scheme
    @State private var showSettings = false
    @State private var showTranscript = false

    private var appState: AppVisualState {
        if stateStore.isUploading { return .uploading }
        if stateStore.isRecording { return .recording }
        return .idle
    }

    var body: some View {
        ZStack {
            // Layer 0: Adaptive gradient background
            LiquidGlass.backgroundGradient(for: scheme)
                .ignoresSafeArea()

            // Layer 1: Ambient depth blobs
            ForEach(Array(LiquidGlass.ambientBlobs(for: scheme).enumerated()), id: \.offset) { _, blob in
                Circle()
                    .fill(blob.color)
                    .frame(width: blob.diameter, height: blob.diameter)
                    .blur(radius: 50)
                    .offset(x: blob.offset.x, y: blob.offset.y)
            }

            // Layer 2: Main content
            VStack(spacing: 0) {
                // Top bar: settings gear
                HStack {
                    Spacer()
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(LiquidGlass.accentGradient.opacity(0.6))
                            .padding(12)
                            .liquidGlassChip()
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // Status badge (visible during recording/uploading)
                if appState != .idle {
                    StatusBadge(
                        elapsedSeconds: stateStore.elapsedSeconds,
                        isRecording: stateStore.isRecording
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .padding(.bottom, 24)
                }

                // Hero glass orb
                GlassOrbButton(
                    isRecording: stateStore.isRecording,
                    isUploading: stateStore.isUploading,
                    isEnabled: !stateStore.isUploading
                ) {
                    Task {
                        if stateStore.isRecording {
                            await stateStore.stopRecording()
                        } else {
                            await stateStore.startRecording()
                        }
                    }
                }

                // Contextual label
                Text(orbLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 16)
                    .contentTransition(.opacity)

                // Status message
                Text(stateStore.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 6)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
            }
            .animation(.spring(duration: LiquidGlass.stateTransition), value: appState)

            // Layer 3: Transcript overlay
            if let transcript = stateStore.lastTranscript, showTranscript {
                VStack {
                    Spacer()
                    TranscriptCard(
                        transcript: transcript,
                        hasPendingCopy: stateStore.hasPendingClipboardCopy,
                        onCopy: { stateStore.copyLastTranscriptToClipboard() },
                        onDismiss: { withAnimation { showTranscript = false } }
                    )
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: stateStore.lastTranscript) { _, newValue in
            if newValue != nil {
                withAnimation(.spring(duration: LiquidGlass.cardSlide)) {
                    showTranscript = true
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
        }
    }

    // MARK: - Helpers

    private var orbLabel: String {
        switch appState {
        case .idle: return "Tap to record"
        case .recording: return "Tap to stop"
        case .uploading: return "Transcribing..."
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(stateStore: .preview)
    }
}
