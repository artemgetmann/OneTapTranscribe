import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var backendURLInput = AppConfig.transcriptionBaseURLString
    @State private var clientTokenInput = AppConfig.clientToken ?? ""
    @State private var configMessage: String?
    @State private var currentBackendURL = AppConfig.transcriptionBaseURLString

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                backendStatusSection
                backendURLSection
                clientTokenSection
                actionsSection

                if let configMessage {
                    Section {
                        Text(configMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(LiquidGlass.accent)
        .presentationDetents([.medium, .large])
    }

    // MARK: - Sections

    private var backendStatusSection: some View {
        Section("Backend Status") {
            VStack(alignment: .leading, spacing: 4) {
                Text(isUsingLocalBackend
                     ? "Localhost (needs laptop)"
                     : "Hosted (works anywhere)")
                    .font(.subheadline.weight(.semibold))
                Text(currentBackendURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var backendURLSection: some View {
        Section {
            TextField("https://your-api.example.com", text: $backendURLInput)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Text("Use hosted HTTPS URL for phone-only usage.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Backend URL")
        }
    }

    private var clientTokenSection: some View {
        Section {
            TextField("Bearer token", text: $clientTokenInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Text("Set this only if backend has APP_CLIENT_TOKEN.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Client Token")
        }
    }

    private var actionsSection: some View {
        Section {
            Button("Save Backend Settings") {
                do {
                    try AppConfig.setTranscriptionBaseURL(backendURLInput)
                    AppConfig.setClientToken(clientTokenInput)
                    refreshSnapshot()
                    configMessage = "Backend settings saved."
                } catch {
                    configMessage = error.localizedDescription
                }
            }

            Button("Reset to bundled defaults", role: .destructive) {
                AppConfig.clearTranscriptionBaseURLOverride()
                AppConfig.setClientToken("")
                refreshSnapshot()
                backendURLInput = AppConfig.transcriptionBaseURLString
                clientTokenInput = AppConfig.clientToken ?? ""
                configMessage = "Backend settings reset."
            }
        }
    }

    // MARK: - Helpers

    private var isUsingLocalBackend: Bool {
        guard let host = URL(string: currentBackendURL)?.host?.lowercased() else {
            return false
        }
        return host == "127.0.0.1" || host == "localhost"
    }

    private func refreshSnapshot() {
        currentBackendURL = AppConfig.transcriptionBaseURLString
    }
}
