import Foundation

nonisolated enum AIEntityKind: String, Codable, Sendable {
    case node
    case module
    case project
}

nonisolated struct AIWorkspaceContext: Codable, Sendable {
    var domainTitle: String?
    var trackTitle: String?
    var moduleTitle: String?
    var projectTitle: String?
    var relatedItems: [AIContextItem]

    static let empty = AIWorkspaceContext(
        domainTitle: nil,
        trackTitle: nil,
        moduleTitle: nil,
        projectTitle: nil,
        relatedItems: []
    )

    init(
        domainTitle: String? = nil,
        trackTitle: String? = nil,
        moduleTitle: String? = nil,
        projectTitle: String? = nil,
        relatedItems: [AIContextItem] = []
    ) {
        self.domainTitle = domainTitle
        self.trackTitle = trackTitle
        self.moduleTitle = moduleTitle
        self.projectTitle = projectTitle
        self.relatedItems = relatedItems
    }
}

nonisolated struct AIContextItem: Codable, Sendable, Identifiable {
    let id: UUID
    let kind: AIEntityKind
    let title: String
    let summary: String

    init(id: UUID, kind: AIEntityKind, title: String, summary: String = "") {
        self.id = id
        self.kind = kind
        self.title = title
        self.summary = summary
    }
}

nonisolated struct AINodeDraft: Codable, Sendable, Equatable {
    let title: String
    let summary: String
    let learningObjectives: [String]
    let keywords: [String]
}

nonisolated struct AIModuleDraft: Codable, Sendable, Equatable {
    let title: String
    let summary: String
    let suggestedNodes: [AINodeDraft]
}

nonisolated struct AIProjectDraft: Codable, Sendable, Equatable {
    let title: String
    let summary: String
    let desiredOutcome: String
    let milestones: [String]
}

nonisolated struct AIGeneration<Value: Codable & Sendable>: Codable, Sendable {
    let value: Value
    let requestID: UUID
    let providerID: String
    let model: String
}

nonisolated enum AIServiceError: LocalizedError, Sendable {
    case emptyPrompt
    case missingCredential
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            return "Describe what you want Sympho to create."
        case .missingCredential:
            return "No OpenAI API key is configured."
        case .invalidResponse:
            return "The AI provider returned a response Sympho could not understand."
        case .requestFailed(let statusCode, let message):
            return "AI request failed (HTTP \(statusCode)): \(message)"
        }
    }
}

nonisolated indirect enum AIJSONSchema: Encodable, Sendable {
    case string
    case array(AIJSONSchema)
    case object(properties: [String: AIJSONSchema], required: [String])

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string:
            try container.encode("string", forKey: .type)
        case .array(let items):
            try container.encode("array", forKey: .type)
            try container.encode(items, forKey: .items)
        case .object(let properties, let required):
            try container.encode("object", forKey: .type)
            try container.encode(properties, forKey: .properties)
            try container.encode(required, forKey: .required)
            try container.encode(false, forKey: .additionalProperties)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, items, properties, required, additionalProperties
    }
}

nonisolated struct AIProviderRequest: Sendable {
    let id: UUID
    let kind: AIEntityKind
    let prompt: String
    let context: AIWorkspaceContext
    let instructions: String
    let schemaName: String
    let schema: AIJSONSchema
}

nonisolated struct AIProviderResponse: Sendable {
    let json: Data
    let providerID: String
    let model: String
}

nonisolated protocol AIModelProvider: Sendable {
    func generate(_ request: AIProviderRequest) async throws -> AIProviderResponse
}
