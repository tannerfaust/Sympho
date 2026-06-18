import Foundation

actor AIService {
    private let provider: any AIModelProvider
    private let decoder = JSONDecoder()

    init(provider: any AIModelProvider) {
        self.provider = provider
    }

    func draftNode(
        from prompt: String,
        context: AIWorkspaceContext = .empty
    ) async throws -> AIGeneration<AINodeDraft> {
        try await generate(
            kind: .node,
            prompt: prompt,
            context: context,
            instructions: "Create a focused learning node. Keep the title concise and make objectives concrete and testable.",
            schemaName: "node_draft",
            schema: .object(
                properties: [
                    "title": .string,
                    "summary": .string,
                    "learningObjectives": .array(.string),
                    "keywords": .array(.string)
                ],
                required: ["title", "summary", "learningObjectives", "keywords"]
            )
        )
    }

    func draftModule(
        from prompt: String,
        context: AIWorkspaceContext = .empty
    ) async throws -> AIGeneration<AIModuleDraft> {
        let nodeSchema = AIJSONSchema.object(
            properties: [
                "title": .string,
                "summary": .string,
                "learningObjectives": .array(.string),
                "keywords": .array(.string)
            ],
            required: ["title", "summary", "learningObjectives", "keywords"]
        )

        return try await generate(
            kind: .module,
            prompt: prompt,
            context: context,
            instructions: "Create a coherent learning module and a short progression of focused nodes.",
            schemaName: "module_draft",
            schema: .object(
                properties: [
                    "title": .string,
                    "summary": .string,
                    "suggestedNodes": .array(nodeSchema)
                ],
                required: ["title", "summary", "suggestedNodes"]
            )
        )
    }

    func draftProject(
        from prompt: String,
        context: AIWorkspaceContext = .empty
    ) async throws -> AIGeneration<AIProjectDraft> {
        try await generate(
            kind: .project,
            prompt: prompt,
            context: context,
            instructions: "Create an outcome-oriented project with a concise sequence of verifiable milestones.",
            schemaName: "project_draft",
            schema: .object(
                properties: [
                    "title": .string,
                    "summary": .string,
                    "desiredOutcome": .string,
                    "milestones": .array(.string)
                ],
                required: ["title", "summary", "desiredOutcome", "milestones"]
            )
        )
    }

    private func generate<Value: Codable & Sendable>(
        kind: AIEntityKind,
        prompt: String,
        context: AIWorkspaceContext,
        instructions: String,
        schemaName: String,
        schema: AIJSONSchema
    ) async throws -> AIGeneration<Value> {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrompt.isEmpty else { throw AIServiceError.emptyPrompt }

        let request = AIProviderRequest(
            id: UUID(),
            kind: kind,
            prompt: cleanPrompt,
            context: context,
            instructions: instructions,
            schemaName: schemaName,
            schema: schema
        )
        let response = try await provider.generate(request)

        do {
            return AIGeneration(
                value: try decoder.decode(Value.self, from: response.json),
                requestID: request.id,
                providerID: response.providerID,
                model: response.model
            )
        } catch {
            throw AIServiceError.invalidResponse
        }
    }
}
