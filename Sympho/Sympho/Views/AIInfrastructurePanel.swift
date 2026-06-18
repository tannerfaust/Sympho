import SwiftUI

struct AIInfrastructurePanel: View {
    @State private var credentialStatus = "Checking…"
    @State private var smokeTestStatus = "Not tested"
    @State private var isTesting = false
    @State private var hasCredential = false
    @State private var apiKey = ""

    var body: some View {
        SettingsSection(title: "AI Infrastructure", iconName: "sparkles") {
            VStack(alignment: .leading, spacing: 12) {
                fact(label: "Credential", value: credentialStatus)
                fact(label: "Pipeline", value: smokeTestStatus)

                if hasCredential {
                    Button("Remove OpenAI Key", role: .destructive) {
                        removeCredential()
                    }
                    .buttonStyle(SymphoSecondaryButtonStyle())
                } else {
                    SecureField("OpenAI API key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)

                    Button("Save Key Securely") {
                        saveCredential()
                    }
                    .buttonStyle(SymphoSecondaryButtonStyle())
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Text("Node, module, and project generation share one typed AI service. Until an API key is connected, requests use a deterministic local provider for safe testing.")
                    .font(.system(size: 11))
                    .foregroundStyle(SymphoTheme.secondaryText)

                Button(isTesting ? "Testing…" : "Run Infrastructure Test") {
                    runSmokeTest()
                }
                .buttonStyle(SymphoSecondaryButtonStyle())
                .disabled(isTesting)
            }
        }
        .task { await refreshCredentialStatus() }
    }

    private func fact(label: String, value: String) -> some View {
        HStack(spacing: 9) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SymphoTheme.secondaryText)
                .frame(width: 72, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(SymphoTheme.primaryText)
        }
    }

    private func refreshCredentialStatus() async {
        do {
            hasCredential = try await AIEnvironment.credentials.apiKey(for: "openai") != nil
            credentialStatus = hasCredential
                ? "OpenAI key secured in Keychain"
                : "Not connected — local test provider active"
        } catch {
            credentialStatus = error.localizedDescription
        }
    }

    private func saveCredential() {
        let value = apiKey
        Task {
            do {
                try await AIEnvironment.credentials.saveAPIKey(value, for: "openai")
                apiKey = ""
                await refreshCredentialStatus()
            } catch {
                credentialStatus = error.localizedDescription
            }
        }
    }

    private func removeCredential() {
        Task {
            do {
                try await AIEnvironment.credentials.deleteAPIKey(for: "openai")
                smokeTestStatus = "Not tested"
                await refreshCredentialStatus()
            } catch {
                credentialStatus = error.localizedDescription
            }
        }
    }

    private func runSmokeTest() {
        isTesting = true
        smokeTestStatus = "Testing…"
        Task {
            defer { isTesting = false }
            do {
                async let node = AIEnvironment.service.draftNode(from: "Understand spaced repetition")
                async let module = AIEnvironment.service.draftModule(from: "Build a practical Swift concurrency module")
                async let project = AIEnvironment.service.draftProject(from: "Ship a small learning dashboard")
                let results = try await (node, module, project)
                let providers = Set([results.0.providerID, results.1.providerID, results.2.providerID])
                smokeTestStatus = "Ready — node, module, and project via \(providers.sorted().joined(separator: ", "))"
            } catch {
                smokeTestStatus = error.localizedDescription
            }
        }
    }
}
