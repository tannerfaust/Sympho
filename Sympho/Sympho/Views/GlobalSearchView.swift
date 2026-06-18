//
//  GlobalSearchView.swift
//  Sympho
//

#if os(macOS)
import SwiftUI
import SwiftData

extension Notification.Name {
    static let showGlobalSearch = Notification.Name("showGlobalSearch")
}

enum GlobalSearchScope: String, CaseIterable, Identifiable {
    case all
    case nodes
    case tags

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .nodes: return "Nodes"
        case .tags: return "Tags"
        }
    }

    var iconName: String {
        switch self {
        case .all: return "line.3.horizontal.decrease.circle"
        case .nodes: return "circle.hexagonpath"
        case .tags: return "tag"
        }
    }
}

private enum GlobalSearchResultKind: String, Hashable {
    case node
    case tag
    case domain
    case track
    case module
    case project
    case resource

    var title: String {
        switch self {
        case .node: return "Node"
        case .tag: return "Tag"
        case .domain: return "Domain"
        case .track: return "Track"
        case .module: return "Module"
        case .project: return "Project"
        case .resource: return "Library"
        }
    }

    var iconName: String {
        switch self {
        case .node: return "circle.hexagonpath.fill"
        case .tag: return "tag.fill"
        case .domain: return "books.vertical.fill"
        case .track: return "point.topleft.down.curvedto.point.bottomright.up"
        case .module: return "square.stack.3d.up.fill"
        case .project: return "folder.fill"
        case .resource: return "doc.text.fill"
        }
    }

    var priority: Int {
        switch self {
        case .node: return 0
        case .tag: return 1
        case .domain: return 2
        case .track: return 3
        case .module: return 4
        case .project: return 5
        case .resource: return 6
        }
    }
}

private struct GlobalSearchResult: Identifiable, Hashable {
    let id: UUID
    let kind: GlobalSearchResultKind
    let title: String
    let subtitle: String
    let searchableText: String
    let colorHex: String?
}

struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Node> { !$0.isDeletedLocally }, sort: \Node.updatedAt, order: .reverse)
    private var nodes: [Node]

    @Query(sort: \LibraryTag.name)
    private var tags: [LibraryTag]

    @Query(
        filter: #Predicate<Domain> { !$0.isArchived && !$0.isDeletedLocally },
        sort: [SortDescriptor(\Domain.sortIndex), SortDescriptor(\Domain.title)]
    )
    private var domains: [Domain]

    @Query(filter: #Predicate<Track> { !$0.isDeletedLocally }, sort: \Track.title)
    private var tracks: [Track]

    @Query(filter: #Predicate<Module> { !$0.isDeletedLocally }, sort: \Module.title)
    private var modules: [Module]

    @Query(filter: #Predicate<Project> { !$0.isDeletedLocally }, sort: \Project.updatedAt, order: .reverse)
    private var projects: [Project]

    @Query(filter: #Predicate<Resource> { !$0.isDeletedLocally }, sort: \Resource.updatedAt, order: .reverse)
    private var resources: [Resource]

    let onOpenNode: (Node) -> Void
    let onOpenTag: (LibraryTag) -> Void
    let onOpenDomain: (Domain) -> Void
    let onOpenTrack: (Track) -> Void
    let onOpenModule: (Module) -> Void
    let onOpenProject: (Project) -> Void
    let onOpenResource: (Resource) -> Void

    @State private var query = ""
    @State private var scope: GlobalSearchScope = .all
    @State private var selectedResultID: UUID?
    @FocusState private var isSearchFocused: Bool

    private var candidates: [GlobalSearchResult] {
        switch scope {
        case .nodes:
            return nodeResults
        case .tags:
            return tagResults
        case .all:
            return nodeResults
                + tagResults
                + domainResults
                + trackResults
                + moduleResults
                + projectResults
                + resourceResults
        }
    }

    private var results: [GlobalSearchResult] {
        let normalizedQuery = normalized(query)

        return candidates.compactMap { result -> (GlobalSearchResult, Int)? in
            guard let score = matchScore(for: result, query: normalizedQuery) else { return nil }
            return (result, score)
        }
        .sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            if lhs.0.kind.priority != rhs.0.kind.priority {
                return lhs.0.kind.priority < rhs.0.kind.priority
            }
            return lhs.0.title.localizedStandardCompare(rhs.0.title) == .orderedAscending
        }
        .prefix(80)
        .map(\.0)
    }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 0) {
                searchField

                scopeBar
                    .padding(.top, 14)
                    .padding(.bottom, 12)

                Divider()

                resultsBody

                Divider()

                footer
            }
            .padding(16)
        }
        .frame(width: 780, height: 590)
        .onAppear {
            selectedResultID = results.first?.id
            Task { @MainActor in
                isSearchFocused = true
            }
        }
        .onChange(of: query) { _, _ in selectFirstResult() }
        .onChange(of: scope) { _, _ in selectFirstResult() }
        .onChange(of: results.map(\.id)) { _, ids in
            if let selectedResultID, ids.contains(selectedResultID) { return }
            self.selectedResultID = ids.first
        }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.return) {
            activateSelection()
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    private var searchField: some View {
        HStack(spacing: 13) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(SymphoTheme.primaryText)

            TextField("Search all of Sympho", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .regular))
                .focused($isSearchFocused)
                .accessibilityLabel("Search all of Sympho")

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 72)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }

    private var scopeBar: some View {
        HStack(spacing: 9) {
            ForEach(GlobalSearchScope.allCases) { candidate in
                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        scope = candidate
                    }
                } label: {
                    Label(candidate.title, systemImage: candidate.iconName)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 13)
                        .frame(height: 34)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(scope == candidate ? SymphoTheme.primaryText : SymphoTheme.secondaryText)
                .glassEffect(
                    scope == candidate ? .regular.interactive() : .clear,
                    in: .capsule
                )
                .accessibilityAddTraits(scope == candidate ? .isSelected : [])
            }

            Spacer()

            Text(resultSummary)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SymphoTheme.tertiaryText)
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var resultsBody: some View {
        if results.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: query.isEmpty ? "sparkle.magnifyingglass" : "magnifyingglass")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(SymphoTheme.tertiaryText)

                Text(query.isEmpty ? "Start typing to search" : "No results")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)

                Text(query.isEmpty ? "Nodes, tags, workspaces, projects, and library entries are searchable." : "Try fewer words or switch the search scope.")
                    .font(.system(size: 12))
                    .foregroundStyle(SymphoTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(results) { result in
                            resultRow(result)
                                .id(result.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.never)
                .onChange(of: selectedResultID) { _, newValue in
                    guard let newValue else { return }
                    withAnimation(.snappy(duration: 0.14)) {
                        proxy.scrollTo(newValue)
                    }
                }
            }
        }
    }

    private func resultRow(_ result: GlobalSearchResult) -> some View {
        let isSelected = selectedResultID == result.id

        return Button {
            selectedResultID = result.id
            activate(result)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(resultColor(for: result).opacity(0.14))

                    Image(systemName: result.kind.iconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(resultColor(for: result))
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(result.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .lineLimit(1)

                    if !result.subtitle.isEmpty {
                        Text(result.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(SymphoTheme.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 12)

                Text(result.kind.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SymphoTheme.tertiaryText)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .glassEffect(.clear, in: .capsule)

                if isSelected {
                    Text("Enter")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .padding(.horizontal, 9)
                        .frame(height: 25)
                        .glassEffect(.regular, in: .capsule)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 62)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? SymphoTheme.primaryText.opacity(0.075) : .clear)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { selectedResultID = result.id }
        }
        .accessibilityLabel("\(result.title), \(result.kind.title)")
        .accessibilityHint("Open result")
    }

    private var footer: some View {
        HStack(spacing: 16) {
            keyboardHint(keys: "↑ ↓", label: "Navigate")
            keyboardHint(keys: "↩", label: "Open")
            keyboardHint(keys: "esc", label: "Close")
            Spacer()
            Text("Search updates as you type")
                .font(.system(size: 10))
                .foregroundStyle(SymphoTheme.tertiaryText)
        }
        .padding(.horizontal, 4)
        .padding(.top, 12)
    }

    private func keyboardHint(keys: String, label: String) -> some View {
        HStack(spacing: 5) {
            Text(keys)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 6)
                .frame(height: 22)
                .glassEffect(.clear, in: .rect(cornerRadius: 6))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(SymphoTheme.tertiaryText)
        }
    }

    private var resultSummary: String {
        let count = results.count
        return "\(count) result\(count == 1 ? "" : "s")"
    }

    private var nodeResults: [GlobalSearchResult] {
        nodes.map { node in
            let hierarchy = [
                node.module?.resolvedDomain?.title ?? node.project?.domain?.title,
                node.project?.title,
                node.module?.title,
                node.status.displayName
            ]
            .compactMap { $0 }

            return GlobalSearchResult(
                id: node.id,
                kind: .node,
                title: node.title,
                subtitle: hierarchy.joined(separator: "  ›  "),
                searchableText: ([node.title, node.desc] + hierarchy).joined(separator: " "),
                colorHex: node.module?.resolvedDomain?.colorHex ?? node.project?.domain?.colorHex
            )
        }
    }

    private var tagResults: [GlobalSearchResult] {
        tags.map { tag in
            let itemCount = tag.resources.count + tag.readingItems.count
            return GlobalSearchResult(
                id: tag.id,
                kind: .tag,
                title: tag.name,
                subtitle: "\(itemCount) linked item\(itemCount == 1 ? "" : "s")",
                searchableText: tag.name,
                colorHex: nil
            )
        }
    }

    private var domainResults: [GlobalSearchResult] {
        domains.map {
            GlobalSearchResult(
                id: $0.id,
                kind: .domain,
                title: $0.title,
                subtitle: $0.desc,
                searchableText: "\($0.title) \($0.desc)",
                colorHex: $0.colorHex
            )
        }
    }

    private var trackResults: [GlobalSearchResult] {
        tracks.map {
            GlobalSearchResult(
                id: $0.id,
                kind: .track,
                title: $0.title,
                subtitle: $0.domain?.title ?? $0.desc,
                searchableText: "\($0.title) \($0.desc) \($0.domain?.title ?? "")",
                colorHex: $0.domain?.colorHex
            )
        }
    }

    private var moduleResults: [GlobalSearchResult] {
        modules.map {
            GlobalSearchResult(
                id: $0.id,
                kind: .module,
                title: $0.title,
                subtitle: [$0.resolvedDomain?.title, $0.track?.title].compactMap { $0 }.joined(separator: "  ›  "),
                searchableText: "\($0.title) \($0.desc) \($0.resolvedDomain?.title ?? "") \($0.track?.title ?? "")",
                colorHex: $0.resolvedDomain?.colorHex
            )
        }
    }

    private var projectResults: [GlobalSearchResult] {
        projects.map {
            let domain = $0.domain ?? $0.track?.domain
            return GlobalSearchResult(
                id: $0.id,
                kind: .project,
                title: $0.title,
                subtitle: domain?.title ?? $0.status.displayName,
                searchableText: "\($0.title) \($0.desc) \(domain?.title ?? "") \($0.status.displayName)",
                colorHex: domain?.colorHex
            )
        }
    }

    private var resourceResults: [GlobalSearchResult] {
        resources.map {
            GlobalSearchResult(
                id: $0.id,
                kind: .resource,
                title: $0.title,
                subtitle: $0.tags.map(\.name).joined(separator: "  ·  "),
                searchableText: "\($0.title) \($0.bodyText) \($0.urlString) \($0.tags.map(\.name).joined(separator: " "))",
                colorHex: $0.domain?.colorHex
            )
        }
    }

    private func selectFirstResult() {
        selectedResultID = results.first?.id
    }

    private func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        guard let selectedResultID,
              let currentIndex = results.firstIndex(where: { $0.id == selectedResultID })
        else {
            self.selectedResultID = results.first?.id
            return
        }

        let nextIndex = min(max(currentIndex + offset, 0), results.count - 1)
        self.selectedResultID = results[nextIndex].id
    }

    private func activateSelection() {
        guard let selectedResultID,
              let result = results.first(where: { $0.id == selectedResultID })
        else { return }
        activate(result)
    }

    private func activate(_ result: GlobalSearchResult) {
        switch result.kind {
        case .node:
            guard let value = nodes.first(where: { $0.id == result.id }) else { return }
            onOpenNode(value)
        case .tag:
            guard let value = tags.first(where: { $0.id == result.id }) else { return }
            onOpenTag(value)
        case .domain:
            guard let value = domains.first(where: { $0.id == result.id }) else { return }
            onOpenDomain(value)
        case .track:
            guard let value = tracks.first(where: { $0.id == result.id }) else { return }
            onOpenTrack(value)
        case .module:
            guard let value = modules.first(where: { $0.id == result.id }) else { return }
            onOpenModule(value)
        case .project:
            guard let value = projects.first(where: { $0.id == result.id }) else { return }
            onOpenProject(value)
        case .resource:
            guard let value = resources.first(where: { $0.id == result.id }) else { return }
            onOpenResource(value)
        }
        dismiss()
    }

    private func matchScore(for result: GlobalSearchResult, query: String) -> Int? {
        guard !query.isEmpty else { return result.kind.priority * 10 }

        let title = normalized(result.title)
        let body = normalized(result.searchableText)
        let words = query.split(separator: " ").map(String.init)

        if title == query { return 0 }
        if title.hasPrefix(query) { return 10 }
        if title.contains(query) { return 20 }
        if body.contains(query) { return 30 }
        if words.allSatisfy({ body.contains($0) }) { return 40 }
        if isSubsequence(query, of: title) { return 50 }
        if isSubsequence(query, of: body) { return 60 }
        return nil
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        guard !needle.isEmpty else { return true }
        var searchIndex = needle.startIndex

        for character in haystack where searchIndex < needle.endIndex {
            if character == needle[searchIndex] {
                searchIndex = needle.index(after: searchIndex)
            }
        }

        return searchIndex == needle.endIndex
    }

    private func resultColor(for result: GlobalSearchResult) -> Color {
        if let colorHex = result.colorHex, let color = Color(hex: colorHex) {
            return color
        }
        return result.kind == .tag ? SymphoTheme.primaryText : SymphoTheme.secondaryText
    }
}
#endif
