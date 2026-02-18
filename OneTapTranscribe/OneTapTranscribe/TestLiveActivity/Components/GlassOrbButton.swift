import SwiftUI

struct GlassOrbButton: View {
    let isRecording: Bool
    let isUploading: Bool
    let isEnabled: Bool
    let action: () -> Void

    // MARK: - Derived State

    private var visualState: AppVisualState {
        if isUploading { return .uploading }
        if isRecording { return .recording }
        return .idle
    }

    private var iconName: String {
        isRecording ? "stop.fill" : "mic.fill"
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            orbContent
                .liquidGlassOrb()
                .overlay {
                    // Gradient tint overlay during recording
                    Circle()
                        .fill(LiquidGlass.accentGradient.opacity(isRecording ? 0.10 : 0))
                        .frame(width: LiquidGlass.orbDiameter, height: LiquidGlass.orbDiameter)
                }
                .pulseGlow(isActive: isRecording)
        }
        .buttonStyle(OrbPressStyle())
        .disabled(!isEnabled)
        .animation(.spring(duration: LiquidGlass.stateTransition), value: visualState)
    }

    // MARK: - Orb Content

    @ViewBuilder
    private var orbContent: some View {
        switch visualState {
        case .uploading:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(LiquidGlass.accent)
                .scaleEffect(1.5)
                .transition(.opacity)

        case .idle, .recording:
            iconView
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if #available(iOS 17.0, *) {
            Image(systemName: iconName)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(LiquidGlass.accentGradient)
                .contentTransition(.symbolEffect(.replace))
        } else {
            Image(systemName: iconName)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(LiquidGlass.accentGradient)
                .id(iconName)
                .transition(.opacity)
        }
    }
}

// MARK: - Press Style

private struct OrbPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
