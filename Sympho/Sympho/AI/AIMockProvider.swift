import Foundation

nonisolated struct AIMockProvider: AIModelProvider {
    private let encoder = JSONEncoder()

    func generate(_ request: AIProviderRequest) async throws -> AIProviderResponse {
        let data: Data
        switch request.kind {
        case .node:
            data = try encoder.encode(AINodeDraft(
                title: conciseTitle(from: request.prompt),
                summary: "A focused learning node generated locally for infrastructure testing.",
                learningObjectives: [
                    "Explain the core concepts in your own words",
                    "Apply the concepts in one practical exercise"
                ],
                keywords: keywords(from: request.prompt)
            ))
        case .module:
            let title = conciseTitle(from: request.prompt)
            data = try encoder.encode(AIModuleDraft(
                title: title,
                summary: "A structured module generated locally for infrastructure testing.",
                suggestedNodes: [
                    node(named: "Foundations of \(title)"),
                    node(named: "Applied \(title)"),
                    node(named: "Review and demonstrate \(title)")
                ]
            ))
        case .project:
            let title = conciseTitle(from: request.prompt)
            data = try encoder.encode(AIProjectDraft(
                title: title,
                summary: "An outcome-oriented project generated locally for infrastructure testing.",
                desiredOutcome: "Produce a working, reviewable result for \(title).",
                milestones: ["Define scope", "Build the first version", "Validate and refine"]
            ))
        }

        return AIProviderResponse(json: data, providerID: "mock", model: "deterministic-v1")
    }

    private func node(named title: String) -> AINodeDraft {
        AINodeDraft(
            title: title,
            summary: "A focused step in the module progression.",
            learningObjectives: ["Understand \(title)", "Demonstrate \(title)"],
            keywords: keywords(from: title)
        )
    }

    private func conciseTitle(from prompt: String) -> String {
        let firstLine = prompt.split(whereSeparator: \.isNewline).first.map(String.init) ?? prompt
        return String(firstLine.prefix(72))
    }

    private func keywords(from text: String) -> [String] {
        Array(
            text.lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count > 3 }
                .prefix(5)
        )
    }
}
