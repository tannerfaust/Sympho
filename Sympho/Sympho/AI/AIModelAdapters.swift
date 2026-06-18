import Foundation

@MainActor
enum AIModelFactory {
    static func node(
        from draft: AINodeDraft,
        sortIndex: Int = 0,
        module: Module? = nil,
        project: Project? = nil
    ) -> Node {
        Node(
            title: draft.title,
            desc: description(summary: draft.summary, items: draft.learningObjectives),
            sortIndex: sortIndex,
            status: .backlog,
            captureIntent: .learningNode,
            module: module,
            project: project
        )
    }

    static func module(
        from draft: AIModuleDraft,
        sortIndex: Int = 0,
        track: Track? = nil,
        domain: Domain? = nil
    ) -> (module: Module, suggestedNodes: [Node]) {
        let module = Module(
            title: draft.title,
            desc: draft.summary,
            sortIndex: sortIndex,
            track: track,
            domain: domain ?? track?.domain
        )
        let nodes = draft.suggestedNodes.enumerated().map { index, nodeDraft in
            node(from: nodeDraft, sortIndex: index, module: module)
        }
        return (module, nodes)
    }

    static func project(
        from draft: AIProjectDraft,
        domain: Domain? = nil,
        track: Track? = nil
    ) -> Project {
        Project(
            title: draft.title,
            desc: description(
                summary: "\(draft.summary)\n\nDesired outcome: \(draft.desiredOutcome)",
                items: draft.milestones
            ),
            status: .backlog,
            domain: domain ?? track?.domain,
            track: track
        )
    }

    private static func description(summary: String, items: [String]) -> String {
        guard !items.isEmpty else { return summary }
        return summary + "\n\n" + items.map { "• \($0)" }.joined(separator: "\n")
    }
}
@MainActor
extension AIWorkspaceContext {
    init(
        domain: Domain? = nil,
        track: Track? = nil,
        module: Module? = nil,
        project: Project? = nil,
        relatedNodes: [Node] = []
    ) {
        self.init(
            domainTitle: domain?.title ?? track?.domain?.title ?? module?.resolvedDomain?.title ?? project?.domain?.title,
            trackTitle: track?.title ?? module?.track?.title ?? project?.track?.title,
            moduleTitle: module?.title,
            projectTitle: project?.title,
            relatedItems: relatedNodes.prefix(20).map {
                AIContextItem(id: $0.id, kind: .node, title: $0.title, summary: $0.desc)
            }
        )
    }
}
