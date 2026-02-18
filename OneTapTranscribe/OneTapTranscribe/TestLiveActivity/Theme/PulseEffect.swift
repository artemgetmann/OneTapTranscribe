import SwiftUI

struct PulseGlowModifier: ViewModifier {
    let isActive: Bool
    let color: Color
    let maxRadius: CGFloat

    @State private var glowing = false

    func body(content: Content) -> some View {
        content
            .shadow(
                color: isActive
                    ? color.opacity(glowing ? 0.5 : 0.2)
                    : .clear,
                radius: isActive
                    ? maxRadius * (glowing ? 1.0 : 0.6)
                    : 0
            )
            .onChange(of: isActive) { _, active in
                if active {
                    withAnimation(
                        .easeInOut(duration: LiquidGlass.pulseFrequency)
                        .repeatForever(autoreverses: true)
                    ) {
                        glowing = true
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        glowing = false
                    }
                }
            }
            .onAppear {
                guard isActive else { return }
                // Kick off initial animation if already active on appear
                withAnimation(
                    .easeInOut(duration: LiquidGlass.pulseFrequency)
                    .repeatForever(autoreverses: true)
                ) {
                    glowing = true
                }
            }
    }
}

extension View {
    func pulseGlow(
        isActive: Bool,
        color: Color = LiquidGlass.accentViolet,
        maxRadius: CGFloat = LiquidGlass.orbRecordingGlowRadius
    ) -> some View {
        modifier(PulseGlowModifier(isActive: isActive, color: color, maxRadius: maxRadius))
    }
}
