import SwiftUI

struct StatusBadge: View {
    let elapsedSeconds: Int
    let isRecording: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Pulsing gradient dot
            Circle()
                .fill(LiquidGlass.accentGradient)
                .frame(width: 8, height: 8)
                .opacity(isRecording ? 1 : 0.4)

            // Monospaced timer
            Text(formattedTime(elapsedSeconds))
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .liquidGlassCard(cornerRadius: 16)
    }

    // MARK: - Helpers

    private func formattedTime(_ total: Int) -> String {
        let minutes = total / 60
        let seconds = total % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
