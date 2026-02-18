import SwiftUI

struct TranscriptCard: View {
    let transcript: String
    let hasPendingCopy: Bool
    let onCopy: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack {
                Text("Transcript")
                    .font(.headline)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .liquidGlassChip()
                }
            }

            // Transcript body
            Text(transcript)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(8)

            // Copy button
            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.doc.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(LiquidGlass.accentGradient))
            }

            // Pending copy hint
            if hasPendingCopy {
                Text("Will auto-copy when app opens")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .liquidGlassCard()
        .padding(.horizontal, 16)
    }
}
