import Foundation

nonisolated struct AIProviderRouter: AIModelProvider {
    let credentialStore: any AICredentialStore
    let fallbackProvider: any AIModelProvider

    func generate(_ request: AIProviderRequest) async throws -> AIProviderResponse {
        guard let apiKey = try await credentialStore.apiKey(for: "openai") else {
            return try await fallbackProvider.generate(request)
        }
        return try await OpenAIProvider(apiKey: apiKey).generate(request)
    }
}

nonisolated enum AIEnvironment {
    static let credentials: any AICredentialStore = KeychainAICredentialStore()

    static let service = AIService(provider: AIProviderRouter(
        credentialStore: credentials,
        fallbackProvider: AIMockProvider()
    ))
}
