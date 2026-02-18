import SwiftUI

enum LiquidGlass {

    // MARK: - Accent Palette (iridescent blue → violet)

    /// Blue end of the gradient — cornflower indigo
    static let accentBlue = Color(red: 0.400, green: 0.494, blue: 0.976)
    /// Violet end of the gradient — vivid orchid
    static let accentViolet = Color(red: 0.769, green: 0.357, blue: 0.988)
    /// Flat midpoint for single-color contexts (tints, widgets)
    static let accent = Color(red: 0.604, green: 0.424, blue: 0.973)

    /// The signature gradient — use on hero elements (icon, buttons, dots)
    static let accentGradient = LinearGradient(
        colors: [accentBlue, accentViolet],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Adaptive Background Gradient

    static func backgroundGradient(for scheme: ColorScheme) -> LinearGradient {
        switch scheme {
        case .dark:
            return LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.04, blue: 0.14),
                    Color(red: 0.08, green: 0.03, blue: 0.12),
                    Color(red: 0.03, green: 0.02, blue: 0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.95, blue: 1.0),
                    Color(red: 0.97, green: 0.95, blue: 1.0),
                    Color(red: 0.99, green: 0.98, blue: 1.0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Ambient Blobs

    struct AmbientBlob {
        let color: Color
        let diameter: CGFloat
        let offset: CGPoint
    }

    static func ambientBlobs(for scheme: ColorScheme) -> [AmbientBlob] {
        let opacity: CGFloat = scheme == .dark ? 0.18 : 0.25
        return [
            AmbientBlob(
                color: accentBlue.opacity(opacity),
                diameter: 300,
                offset: CGPoint(x: -100, y: -280)
            ),
            AmbientBlob(
                color: accentViolet.opacity(opacity),
                diameter: 340,
                offset: CGPoint(x: 160, y: -150)
            ),
            AmbientBlob(
                color: accentBlue.opacity(opacity * 0.5),
                diameter: 200,
                offset: CGPoint(x: 120, y: 300)
            ),
        ]
    }

    // MARK: - Glass Border Colors (refractive edge)

    static func glassBorderTop(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white.opacity(0.18) : .white.opacity(0.7)
    }

    static func glassBorderBottom(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white.opacity(0.04) : .white.opacity(0.15)
    }

    // MARK: - Orb

    static let orbDiameter: CGFloat = 180
    static let orbRecordingGlowRadius: CGFloat = 40

    // MARK: - Animation Timings (snappy)

    static let stateTransition: Double = 0.3
    static let pulseFrequency: Double = 1.8
    static let cardSlide: Double = 0.35

    // MARK: - Layout

    static let cardCornerRadius: CGFloat = 24
    static let chipCornerRadius: CGFloat = 16
}

// MARK: - Visual State

enum AppVisualState {
    case idle, recording, uploading
}
