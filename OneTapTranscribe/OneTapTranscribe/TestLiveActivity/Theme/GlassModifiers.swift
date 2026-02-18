import SwiftUI

// MARK: - Primary Glass Card

struct LiquidGlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(scheme == .dark ? .ultraThinMaterial : .thinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                LiquidGlass.glassBorderTop(for: scheme),
                                LiquidGlass.glassBorderBottom(for: scheme),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            }
            .shadow(
                color: .black.opacity(scheme == .dark ? 0.3 : 0.08),
                radius: 20, y: 10
            )
    }
}

// MARK: - Secondary Glass Chip (circle)

struct LiquidGlassChipModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: Circle())
            .overlay {
                Circle().strokeBorder(
                    Color.white.opacity(scheme == .dark ? 0.12 : 0.4),
                    lineWidth: 0.5
                )
            }
    }
}

// MARK: - Glass Orb (circular card)

struct LiquidGlassOrbModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let diameter: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(width: diameter, height: diameter)
            .background {
                Circle()
                    .fill(scheme == .dark ? .ultraThinMaterial : .thinMaterial)
            }
            .overlay {
                // Refractive gradient border
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                LiquidGlass.glassBorderTop(for: scheme),
                                LiquidGlass.glassBorderBottom(for: scheme),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .overlay {
                // Inner convex shadow for depth
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.clear, .black.opacity(scheme == .dark ? 0.15 : 0.05)],
                            center: .center,
                            startRadius: diameter * 0.3,
                            endRadius: diameter * 0.5
                        )
                    )
            }
            .shadow(
                color: .black.opacity(scheme == .dark ? 0.4 : 0.1),
                radius: 30, y: 15
            )
    }
}

// MARK: - View Extensions

extension View {
    func liquidGlassCard(cornerRadius: CGFloat = LiquidGlass.cardCornerRadius) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius))
    }

    func liquidGlassChip() -> some View {
        modifier(LiquidGlassChipModifier())
    }

    func liquidGlassOrb(diameter: CGFloat = LiquidGlass.orbDiameter) -> some View {
        modifier(LiquidGlassOrbModifier(diameter: diameter))
    }
}
