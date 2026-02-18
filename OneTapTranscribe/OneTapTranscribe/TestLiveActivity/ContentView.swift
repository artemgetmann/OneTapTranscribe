import SwiftUI

struct ContentView: View {
    @ObservedObject var stateStore: RecordingStateStore

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.93, green: 0.95, blue: 1.0), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.cyan.opacity(0.25))
                .frame(width: 260, height: 260)
                .blur(radius: 44)
                .offset(x: -120, y: -250)

            Circle()
                .fill(Color.indigo.opacity(0.22))
                .frame(width: 300, height: 300)
                .blur(radius: 58)
                .offset(x: 150, y: -180)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("OneTapTranscribe")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .tracking(-0.4)
                        Text("Instant voice capture and transcript")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                    VStack(spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(stateStore.isRecording ? .red : .gray.opacity(0.6))
                                    .frame(width: 9, height: 9)
                                Text(stateStore.isUploading ? "Uploading" : (stateStore.isRecording ? "Recording" : "Idle"))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(formattedTime(stateStore.elapsedSeconds))
                                .font(.system(size: 34, weight: .bold, design: .monospaced))
                                .contentTransition(.numericText())
                        }

                        LiquidWaveformView(
                            isActive: stateStore.isRecording && !stateStore.isUploading,
                            barColor: stateStore.isRecording ? .red : .gray
                        )
                        .frame(height: 28)

                        Text(stateStore.statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(18)
                    .glassCard()

                    HStack(spacing: 12) {
                        GlassActionButton(
                            title: "Start",
                            systemImage: "play.fill",
                            color: .green,
                            isEnabled: !stateStore.isRecording && !stateStore.isUploading
                        ) {
                            Task { await stateStore.startRecording() }
                        }

                        GlassActionButton(
                            title: "Stop",
                            systemImage: "stop.fill",
                            color: .red,
                            isEnabled: stateStore.isRecording
                        ) {
                            Task { await stateStore.stopRecording() }
                        }
                    }

                    if stateStore.isUploading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Uploading and transcribing...")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .glassCard()
                    }

                    if let lastTranscript = stateStore.lastTranscript {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Latest transcript")
                                .font(.headline)
                            Text(lastTranscript)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(5)

                            Button("Copy transcript again") {
                                stateStore.copyLastTranscriptToClipboard()
                            }
                            .font(.footnote.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .glassCard()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Quick test")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Start, leave app, tap Stop from Dynamic Island, verify transcript copied.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .glassCard()
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private func formattedTime(_ totalSeconds: Int) -> String {
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

private struct GlassActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isEnabled ? color : Color.gray.opacity(0.5))
                )
        }
        .disabled(!isEnabled)
        .shadow(color: color.opacity(isEnabled ? 0.28 : 0), radius: 12, y: 6)
    }
}

private struct LiquidWaveformView: View {
    let isActive: Bool
    let barColor: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            HStack(spacing: 4) {
                ForEach(0..<22, id: \.self) { index in
                    let phase = t * 4.8 + Double(index) * 0.35
                    let base = isActive ? 8.0 : 4.0
                    let amplitude = isActive ? 12.0 : 1.4
                    let height = base + (sin(phase) + 1) * 0.5 * amplitude

                    Capsule(style: .continuous)
                        .fill(barColor.opacity(isActive ? 0.9 : 0.35))
                        .frame(width: 3, height: height)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isActive)
        }
    }
}

private extension View {
    func glassCard() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 22, y: 10)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(stateStore: .preview)
    }
}
