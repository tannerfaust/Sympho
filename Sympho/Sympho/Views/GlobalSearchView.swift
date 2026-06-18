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

struct GlobalSearchActions {
    let openNode: (Node) -> Void
    let openTag: (LibraryTag) -> Void
    let openDomain: (Domain) -> Void
    let openTrack: (Track) -> Void
    let openModule: (Module) -> Void
    let openProject: (Project) -> Void
    let openResource: (Resource) -> Void
}

enum GlobalSearchScope: String, CaseIterable, Identifiable {
    case all
    case nodes
    case domains
    case projects
    case library
    case tags

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Everywhere"
        case .nodes: return "Knowledge"
        case .domains: return "Workspaces"
        case .projects: return "Projects"
        case .library: return "References"
        case .tags: return "Tags"
        }
    }

    var iconName: String {
        switch self {
        case .all: return "line.3.horizontal.decrease.circle"
        case .nodes: return "circle.hexagonpath"
        case .domains: return "building.columns"
        case .projects: return "folder"
        case .library: return "books.vertical"
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
        case .node: return "Note"
        case .tag: return "Tag"
        case .domain: return "Workspace"
        case .track: return "Track"
        case .module: return "Module"
        case .project: return "Project"
        case .resource: return "Reference"
        }
    }

    var category: GlobalSearchScope {
        switch self {
        case .node: return .nodes
        case .domain, .track, .module: return .domains
        case .project: return .projects
        case .resource: return .library
        case .tag: return .tags
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
        case .module: return 1
        case .domain: return 2
        case .track: return 3
        case .project: return 4
        case .resource: return 5
        case .tag: return 6
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

private enum GlobalSearchDisplayCategory: Hashable {
    case bestMatch
    case knowledge
    case workspaces
    case references

    var title: String {
        switch self {
        case .bestMatch: return "Best Match"
        case .knowledge: return "Knowledge"
        case .workspaces: return "Workspaces"
        case .references: return "References"
        }
    }
}

private struct GlobalSearchDisplaySection: Identifiable {
    let category: GlobalSearchDisplayCategory
    let results: [GlobalSearchResult]

    var id: GlobalSearchDisplayCategory { category }
}

struct GlobalSearchView: View {
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

    let actions: GlobalSearchActions
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var scope: GlobalSearchScope = .all
    @State private var selectedResultID: UUID?
    @State private var keyboardScrollTargetID: UUID?
    @FocusState private var isSearchFocused: Bool

    private let panelWidth: CGFloat = 560
    private let panelMaxHeight: CGFloat = 520
    private let panelCornerRadius: CGFloat = 22
    private let editedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    private var candidates: [GlobalSearchResult] {
        let all = nodeResults
            + moduleResults
            + domainResults
            + trackResults
            + projectResults
            + resourceResults
            + tagResults

        guard scope != .all else { return all }
        return all.filter { $0.kind.category == scope }
    }

    private var results: [GlobalSearchResult] {
        let normalizedQuery = normalized(query)
        guard !normalizedQuery.isEmpty else { return suggestedResults }

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
        .prefix(60)
        .map(\.0)
    }

    private var suggestedResults: [GlobalSearchResult] {
        let suggestions: [GlobalSearchResult]
        switch scope {
        case .all:
            suggestions = Array(nodeResults.prefix(5))
                + Array(moduleResults.prefix(2))
                + Array(domainResults.prefix(3))
                + Array(projectResults.prefix(2))
                + Array(resourceResults.prefix(3))
                + Array(tagResults.prefix(3))
        case .nodes:
            suggestions = Array(nodeResults.prefix(15))
        case .domains:
            suggestions = Array(domainResults.prefix(5))
                + Array(trackResults.prefix(5))
                + Array(moduleResults.prefix(5))
        case .projects:
            suggestions = Array(projectResults.prefix(15))
        case .library:
            suggestions = Array(resourceResults.prefix(15))
        case .tags:
            suggestions = Array(tagResults.prefix(15))
        }
        return suggestions
    }

    private var displaySections: [GlobalSearchDisplaySection] {
        guard scope == .all else {
            guard !results.isEmpty else { return [] }
            let category: GlobalSearchDisplayCategory
            switch scope {
            case .nodes: category = .knowledge
            case .domains, .projects: category = .workspaces
            case .library, .tags: category = .references
            case .all: category = .knowledge
            }
            return [GlobalSearchDisplaySection(category: category, results: results)]
        }

        let bestMatch = normalized(query).isEmpty ? nil : results.first
        let remaining = bestMatch.map { best in results.filter { $0.id != best.id } } ?? results

        var sections: [GlobalSearchDisplaySection] = []

        if let bestMatch {
            sections.append(GlobalSearchDisplaySection(category: .bestMatch, results: [bestMatch]))
        }

        let knowledge = remaining.filter { [.node, .module, .track].contains($0.kind) }
        let workspaces = remaining.filter { [.domain, .project].contains($0.kind) }
        let references = remaining.filter { [.resource, .tag].contains($0.kind) }

        if !knowledge.isEmpty {
            sections.append(GlobalSearchDisplaySection(category: .knowledge, results: knowledge))
        }
        if !workspaces.isEmpty {
            sections.append(GlobalSearchDisplaySection(category: .workspaces, results: workspaces))
        }
        if !references.isEmpty {
            sections.append(GlobalSearchDisplaySection(category: .references, results: references))
        }

        return sections
    }

    var body: some View {
        VStack(spacing: 0) {
            searchHeader

            Divider()
                .overlay(SymphoTheme.dividerColor)

            resultsBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .overlay(SymphoTheme.dividerColor)

            searchFooter
        }
        .frame(width: panelWidth, height: panelMaxHeight, alignment: .top)
        .glassEffect(.regular, in: .rect(cornerRadius: panelCornerRadius))
        .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
        .background {
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                .fill(.white.opacity(0.01))
                .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
        }
        .onAppear {
            Task { @MainActor in isSearchFocused = true }
            selectedResultID = results.first?.id
        }
        .onChange(of: query) { _, _ in
            selectedResultID = results.first?.id
            keyboardScrollTargetID = nil
        }
        .onChange(of: scope) { _, _ in
            selectedResultID = results.first?.id
            keyboardScrollTargetID = nil
        }
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
            onDismiss()
            return .handled
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SymphoTheme.tertiaryText)

            TextField("Search Sympho", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .regular))
                .focused($isSearchFocused)
                .accessibilityLabel("Search Sympho")

            scopeMenu

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.small)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .contentShape(Rectangle())
        .onTapGesture { isSearchFocused = true }
    }

    private var scopeMenu: some View {
        Menu {
            ForEach(GlobalSearchScope.allCases) { candidate in
                Button {
                    scope = candidate
                } label: {
                    if scope == candidate {
                        Label(candidate.title, systemImage: "checkmark")
                    } else {
                        Text(candidate.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(scope.title)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(SymphoTheme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var searchFooter: some View {
        HStack(spacing: 18) {
            footerHint(keys: "↑ ↓", label: "to navigate")
            footerHint(keys: "↵", label: "to open")
            Spacer()
            footerHint(keys: "⌘K", label: "for commands")
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
    }

    private func footerHint(keys: String, label: String) -> some View {
        HStack(spacing: 5) {
            Text(keys)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(SymphoTheme.secondaryText)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .glassEffect(.regular, in: .rect(cornerRadius: 4))

            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(SymphoTheme.tertiaryText)
        }
    }

    @ViewBuilder
    private var resultsBody: some View {
        if results.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(SymphoTheme.tertiaryText)

                Text("Nothing found")
                    .font(.system(size: 14, weight: .semibold))

                Text("Try another phrase or scope.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(SymphoTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        ForEach(displaySections) { section in
                            sectionHeader(section)

                            ForEach(section.results) { result in
                                resultRow(result, in: section.category)
                                    .id(result.id)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .scrollIndicators(.never)
                .onChange(of: keyboardScrollTargetID) { _, target in
                    guard let target else { return }
                    withAnimation(.snappy(duration: 0.14)) {
                        proxy.scrollTo(target)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ section: GlobalSearchDisplaySection) -> some View {
        HStack(spacing: 8) {
            Text(section.category.title)
                .textCase(.uppercase)

            Spacer()

            if section.category != .bestMatch {
                Text("\(section.results.count)")
                    .monospacedDigit()
            }
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(SymphoTheme.tertiaryText)
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(SymphoTheme.dividerColor)
                .frame(height: 1)
                .padding(.horizontal, -4)
        }
    }

    private func resultRow(_ result: GlobalSearchResult, in section: GlobalSearchDisplayCategory) -> some View {
        let isSelected = selectedResultID == result.id
        let isBestMatch = section == .bestMatch

        return Button {
            selectedResultID = result.id
            activate(result)
        } label: {
            rowContent(result: result, section: section, isSelected: isSelected, isBestMatch: isBestMatch)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { selectedResultID = result.id }
        }
        .accessibilityLabel("\(result.title), \(result.kind.title)")
        .accessibilityHint("Open result")
    }

    @ViewBuilder
    private func rowContent(
        result: GlobalSearchResult,
        section: GlobalSearchDisplayCategory,
        isSelected: Bool,
        isBestMatch: Bool
    ) -> some View {
        let content = HStack(spacing: 11) {
            resultIcon(for: result, in: section)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(result.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .lineLimit(1)

                    if isBestMatch, result.kind == .node {
                        Text("Note")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(SymphoTheme.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .glassEffect(.regular, in: .capsule)
                    }
                }

                if let subtitle = rowSubtitle(for: result, in: section), !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(SymphoTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 10)

            if !isBestMatch {
                Text(trailingLabel(for: result))
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundStyle(SymphoTheme.tertiaryText)
                    .lineLimit(1)
            }

            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, isBestMatch ? 10 : 8)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

        if isBestMatch {
            content.glassEffect(.regular, in: .rect(cornerRadius: 10))
        } else if isSelected {
            content
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(SymphoTheme.elevatedCanvas.opacity(0.72))
                }
        } else {
            content
        }
    }

    @ViewBuilder
    private func resultIcon(for result: GlobalSearchResult, in section: GlobalSearchDisplayCategory) -> some View {
        switch section {
        case .workspaces where result.kind == .domain || result.kind == .project:
            Image(systemName: workspaceIconName(for: result))
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(SymphoTheme.secondaryText)
                .frame(width: 28, height: 28)

        case .references:
            Image(systemName: referenceIconName(for: result))
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(SymphoTheme.secondaryText)
                .frame(width: 28, height: 28)

        default:
            ZStack {
                Circle()
                    .fill(resultColor(for: result).opacity(0.14))

                Image(systemName: result.kind.iconName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(resultColor(for: result))
            }
            .frame(width: 28, height: 28)
        }
    }

    private func rowSubtitle(for result: GlobalSearchResult, in section: GlobalSearchDisplayCategory) -> String? {
        if section == .bestMatch, result.kind == .node,
           let node = nodes.first(where: { $0.id == result.id }) {
            return "Edited \(editedDateFormatter.string(from: node.updatedAt))"
        }
        return result.subtitle.nonEmpty
    }

    private func trailingLabel(for result: GlobalSearchResult) -> String {
        switch result.kind {
        case .node, .module, .track:
            return result.kind.title
        case .domain:
            let count = domains.first(where: { $0.id == result.id })?.allNodes.count ?? 0
            return "\(count) node\(count == 1 ? "" : "s")"
        case .project:
            let count = projects.first(where: { $0.id == result.id })?.nodes.filter { !$0.isDeletedLocally }.count ?? 0
            return "\(count) node\(count == 1 ? "" : "s")"
        case .resource:
            if let resource = resources.first(where: { $0.id == result.id }) {
                return resourceTypeDisplayName(resource.resourceType)
            }
            return "Reference"
        case .tag:
            return "Tag"
        }
    }

    private func workspaceIconName(for result: GlobalSearchResult) -> String {
        switch result.kind {
        case .domain:
            if let domain = domains.first(where: { $0.id == result.id }) {
                return DomainIcon.validated(domain.iconName)
            }
            return "building.columns"
        case .project:
            return "folder"
        default:
            return result.kind.iconName
        }
    }

    private func referenceIconName(for result: GlobalSearchResult) -> String {
        guard result.kind == .resource,
              let resource = resources.first(where: { $0.id == result.id }) else {
            return result.kind.iconName
        }
        return resource.resourceType.iconName
    }

    private func resourceTypeDisplayName(_ type: ResourceType) -> String {
        switch type {
        case .pdf: return "PDF Document"
        case .url: return "Web Link"
        case .video: return "Video"
        case .note: return "Note"
        }
    }

    private var nodeResults: [GlobalSearchResult] {
        nodes.map { node in
            let hierarchy = [
                node.module?.resolvedDomain?.title ?? node.project?.domain?.title,
                node.project?.title,
                node.module?.title,
                node.status.displayName
            ].compactMap { $0 }

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
            GlobalSearchResult(id: $0.id, kind: .domain, title: $0.title, subtitle: $0.desc,
                               searchableText: "\($0.title) \($0.desc)", colorHex: $0.colorHex)
        }
    }

    private var trackResults: [GlobalSearchResult] {
        tracks.map {
            GlobalSearchResult(id: $0.id, kind: .track, title: $0.title,
                               subtitle: $0.domain?.title ?? $0.desc,
                               searchableText: "\($0.title) \($0.desc) \($0.domain?.title ?? "")",
                               colorHex: $0.domain?.colorHex)
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
            return GlobalSearchResult(id: $0.id, kind: .project, title: $0.title,
                                      subtitle: domain?.title ?? $0.status.displayName,
                                      searchableText: "\($0.title) \($0.desc) \(domain?.title ?? "") \($0.status.displayName)",
                                      colorHex: domain?.colorHex)
        }
    }

    private var resourceResults: [GlobalSearchResult] {
        resources.map {
            GlobalSearchResult(id: $0.id, kind: .resource, title: $0.title,
                               subtitle: $0.tags.map(\.name).joined(separator: "  ·  "),
                               searchableText: "\($0.title) \($0.bodyText) \($0.urlString) \($0.tags.map(\.name).joined(separator: " "))",
                               colorHex: $0.domain?.colorHex)
        }
    }

    private func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        guard let selectedResultID,
              let currentIndex = results.firstIndex(where: { $0.id == selectedResultID })
        else {
            self.selectedResultID = results.first?.id
            keyboardScrollTargetID = results.first?.id
            return
        }

        let nextIndex = min(max(currentIndex + offset, 0), results.count - 1)
        let nextID = results[nextIndex].id
        self.selectedResultID = nextID
        keyboardScrollTargetID = nextID
    }

    private func activateSelection() {
        guard let selectedResultID,
              let result = results.first(where: { $0.id == selectedResultID })
        else { return }
        activate(result)
    }

    private func activate(_ result: GlobalSearchResult) {
        onDismiss()
        switch result.kind {
        case .node:
            if let value = nodes.first(where: { $0.id == result.id }) { actions.openNode(value) }
        case .tag:
            if let value = tags.first(where: { $0.id == result.id }) { actions.openTag(value) }
        case .domain:
            if let value = domains.first(where: { $0.id == result.id }) { actions.openDomain(value) }
        case .track:
            if let value = tracks.first(where: { $0.id == result.id }) { actions.openTrack(value) }
        case .module:
            if let value = modules.first(where: { $0.id == result.id }) { actions.openModule(value) }
        case .project:
            if let value = projects.first(where: { $0.id == result.id }) { actions.openProject(value) }
        case .resource:
            if let value = resources.first(where: { $0.id == result.id }) { actions.openResource(value) }
        }
    }

    private func matchScore(for result: GlobalSearchResult, query: String) -> Int? {
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
        var searchIndex = needle.startIndex
        for character in haystack where searchIndex < needle.endIndex {
            if character == needle[searchIndex] {
                searchIndex = needle.index(after: searchIndex)
            }
        }
        return searchIndex == needle.endIndex
    }

    private func resultColor(for result: GlobalSearchResult) -> Color {
        if let colorHex = result.colorHex, let color = Color(hex: colorHex) { return color }
        return result.kind == .tag ? SymphoTheme.primaryText : SymphoTheme.secondaryText
    }
}

private extension String {
    var nonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
#endif
