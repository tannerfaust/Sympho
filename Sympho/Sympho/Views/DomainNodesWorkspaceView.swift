//
//  DomainNodesWorkspaceView.swift
//  Sympho
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Workspace

struct DomainNodesWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext

    let domain: Domain
    let nodes: [Node]
    var track: Track? = nil
    var module: Module? = nil
    var onSelectNode: (Node) -> Void
    var onEditNode: (Node) -> Void

    @State private var viewMode: DomainNodesViewMode = .cards
    @State private var sort: DomainNodesSort = .updated
    @State private var group: DomainNodesGroup = .none
    @State private var statusFilter: DomainNodesStatusFilter = .all
    @State private var criticalOnly = false
    @State private var draggedNodeID: UUID?
    @State private var showInlineAddNode = false
    @State private var newNodeTitle = ""

    private var filteredSortedNodes: [Node] {
        var list = nodes
        if statusFilter != .all {
            list = list.filter { $0.status == statusFilter.nodeStatus }
        }
        if criticalOnly {
            list = list.filter { $0.priority == .critical }
        }
        return sortNodes(list)
    }

    private var cardSections: [DomainNodeSection] {
        switch group {
        case .none:
            return [DomainNodeSection(id: "all", title: "", iconName: "", nodes: filteredSortedNodes)]
        case .module:
            return groupedSections(key: { DomainNodeGrouping.moduleKey(for: $0) }, title: { DomainNodeGrouping.moduleTitle(for: $0) }, icon: "square.stack.3d.up")
        case .track:
            return groupedSections(key: { DomainNodeGrouping.trackKey(for: $0) }, title: { DomainNodeGrouping.trackTitle(for: $0) }, icon: "point.topleft.down.curvedto.point.bottomright.up")
        }
    }

    private var canAddNodes: Bool {
        if module != nil { return true }
        if track != nil { return !(track?.activeModules.isEmpty ?? true) }
        return !domain.modules.isEmpty || domain.tracks.contains { !$0.activeModules.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            nodesToolbar

            if showInlineAddNode {
                inlineAddNodeField
            }

            if nodes.isEmpty {
                Text(emptyNodesMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .padding(.vertical, 8)
            } else if filteredSortedNodes.isEmpty {
                Text("No nodes match these filters.")
                    .font(.system(size: 12))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                switch viewMode {
                case .cards:
                    nodesCardsView
                case .kanban:
                    nodesKanbanView
                }
            }
        }
    }

    // MARK: - Toolbar

    private var nodesToolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                nodesModeButton(title: "Cards", mode: .cards, icon: "square.grid.2x2")
                nodesModeButton(title: "Kanban", mode: .kanban, icon: "rectangle.split.3x1")
            }
            .padding(2)
            .glassEffect(.regular.interactive(), in: .capsule)

            Spacer(minLength: 0)

            nodesFilterChip(
                title: statusFilter.title,
                icon: statusFilter.iconName,
                isActive: statusFilter != .all
            ) {
                statusFilterMenu
            }

            nodesFilterChip(
                title: criticalOnly ? "Critical" : "Priority",
                icon: "exclamationmark.triangle",
                isActive: criticalOnly
            ) {
                criticalFilterMenu
            }

            nodesFilterChip(title: sort.shortTitle, icon: "arrow.up.arrow.down", isActive: sort != .updated) {
                sortMenu
            }

            if viewMode == .cards, module == nil {
                nodesFilterChip(title: group.shortTitle, icon: "rectangle.3.group", isActive: group != .none) {
                    groupMenu
                }
            }

            Button {
                withAnimation(.snappy(duration: 0.15)) {
                    showInlineAddNode.toggle()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help(canAddNodes ? "Add node" : "Add a module first")
            .disabled(!canAddNodes)
        }
    }

    private var emptyNodesMessage: String {
        if track != nil, !canAddNodes {
            return "No nodes yet. Add a module on the Modules tab first."
        }
        return "No nodes yet. Use + to add one."
    }

    private var inlineAddNodeField: some View {
        HStack(spacing: 8) {
            TextField("Node title…", text: $newNodeTitle, onCommit: saveNewNode)
                .textFieldStyle(.plain)
                .padding(.horizontal, 11)
                .frame(height: 38)
                .background {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(SymphoTheme.elevatedCanvas.opacity(0.58))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                }

            Button("Add", action: saveNewNode)
                .buttonStyle(SymphoPrimaryButtonStyle())
        }
        .transition(.opacity)
    }

    private func saveNewNode() {
        let title = newNodeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let module = targetModuleForNewNode else { return }

        let newNode = Node(
            title: title,
            desc: "",
            status: .backlog,
            priority: .normal,
            module: module
        )
        modelContext.insert(newNode)
        module.nodes.append(newNode)
        module.isSynced = false
        module.updatedAt = Date()
        track?.isSynced = false
        track?.updatedAt = Date()
        domain.isSynced = false
        domain.updatedAt = Date()
        try? modelContext.save()

        newNodeTitle = ""
        showInlineAddNode = false
        onSelectNode(newNode)
    }

    private var targetModuleForNewNode: Module? {
        if let module {
            return module
        }
        if let track {
            return track.activeModules.first
        }
        if let standalone = domain.modules.filter({ !$0.isDeletedLocally }).first {
            return standalone
        }
        return domain.tracks.flatMap(\.activeModules).first
    }

    private func nodesModeButton(title: String, mode: DomainNodesViewMode, icon: String) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) {
                viewMode = mode
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if viewMode == mode {
                    Capsule().fill(SymphoTheme.primaryText)
                }
            }
            .foregroundStyle(viewMode == mode ? SymphoTheme.primaryCanvas : SymphoTheme.secondaryText)
        }
        .buttonStyle(.plain)
    }

    private func nodesFilterChip<MenuContent: View>(
        title: String,
        icon: String,
        isActive: Bool,
        @ViewBuilder menu: () -> MenuContent
    ) -> some View {
        Menu {
            menu()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isActive ? SymphoTheme.primaryText : SymphoTheme.secondaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(isActive ? SymphoTheme.elevatedCanvas.opacity(0.95) : SymphoTheme.elevatedCanvas.opacity(0.45))
            }
            .overlay {
                Capsule()
                    .stroke(isActive ? SymphoTheme.primaryText.opacity(0.12) : SymphoTheme.dividerColor, lineWidth: 1)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    @ViewBuilder
    private var statusFilterMenu: some View {
        ForEach(DomainNodesStatusFilter.allCases) { option in
            Button {
                statusFilter = option
            } label: {
                Label(option.title, systemImage: option.iconName)
            }
        }
    }

    @ViewBuilder
    private var criticalFilterMenu: some View {
        Button {
            criticalOnly = false
        } label: {
            Label("All priorities", systemImage: "line.3.horizontal.decrease")
        }
        Button {
            criticalOnly = true
        } label: {
            Label("Critical only", systemImage: "exclamationmark.triangle.fill")
        }
    }

    @ViewBuilder
    private var sortMenu: some View {
        ForEach(DomainNodesSort.allCases) { option in
            Button {
                sort = option
            } label: {
                Label(option.title, systemImage: option.iconName)
            }
        }
    }

    @ViewBuilder
    private var groupMenu: some View {
        ForEach(DomainNodesGroup.allCases) { option in
            Button {
                group = option
            } label: {
                Label(option.title, systemImage: option.iconName)
            }
        }
    }

    // MARK: - Cards

    private var nodesCardsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(cardSections.filter { !$0.nodes.isEmpty }) { section in
                if group != .none, !section.title.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: section.iconName)
                            .font(.system(size: 11, weight: .semibold))
                        Text(section.title)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(SymphoTheme.secondaryText)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                    ForEach(section.nodes) { node in
                        DomainNodeCard(
                            node: node,
                            domainTitle: domain.title,
                            onOpen: { onSelectNode(node) },
                            onEdit: { onEditNode(node) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Kanban

    private var nodesKanbanView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(NodeStatus.allCases) { status in
                    kanbanColumn(status: status)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func kanbanColumn(status: NodeStatus) -> some View {
        let columnNodes = filteredSortedNodes.filter { $0.status == status }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: DomainNodeVisuals.statusIcon(status))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DomainNodeVisuals.statusColor(status))
                Text(status.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)
                Spacer(minLength: 0)
                Text("\(columnNodes.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(columnNodes) { node in
                        DomainNodeKanbanCard(
                            node: node,
                            domainTitle: domain.title,
                            onOpen: { onSelectNode(node) },
                            onEdit: { onEditNode(node) }
                        )
                        #if os(macOS)
                        .onDrag {
                            draggedNodeID = node.id
                            return NSItemProvider(object: node.id.uuidString as NSString)
                        }
                        #endif
                    }
                }
                .padding(.bottom, 4)
            }
            .frame(minHeight: 120, maxHeight: 440)
        }
        .frame(width: 232)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SymphoTheme.elevatedCanvas.opacity(0.42))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        }
        #if os(macOS)
        .onDrop(
            of: [.text],
            delegate: NodeKanbanColumnDropDelegate(
                targetStatus: status,
                draggedNodeID: $draggedNodeID,
                onAssign: assignNode(_:to:)
            )
        )
        #endif
    }

    // MARK: - Data

    private func sortNodes(_ list: [Node]) -> [Node] {
        switch sort {
        case .updated:
            return list.sorted { $0.updatedAt > $1.updatedAt }
        case .title:
            return list.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .status:
            return list.sorted { statusRank($0.status) < statusRank($1.status) }
        case .module:
            return list.sorted {
                DomainNodeGrouping.moduleTitle(for: $0).localizedCaseInsensitiveCompare(
                    DomainNodeGrouping.moduleTitle(for: $1)
                ) == .orderedAscending
            }
        }
    }

    private func statusRank(_ status: NodeStatus) -> Int {
        switch status {
        case .backlog: return 0
        case .active: return 1
        case .mastered: return 2
        }
    }

    private func groupedSections(
        key: (Node) -> String,
        title: (Node) -> String,
        icon: String
    ) -> [DomainNodeSection] {
        let grouped = Dictionary(grouping: filteredSortedNodes, by: key)
        return grouped.keys.sorted().map { sectionKey in
            let sectionNodes = grouped[sectionKey] ?? []
            return DomainNodeSection(
                id: sectionKey,
                title: title(sectionNodes.first!),
                iconName: icon,
                nodes: sortNodes(sectionNodes)
            )
        }
    }

    private func assignNode(_ nodeID: UUID, to status: NodeStatus) {
        guard let node = nodes.first(where: { $0.id == nodeID }) else { return }
        guard node.status != status else { return }
        node.status = status
        node.updatedAt = Date()
        domain.updatedAt = Date()
        domain.isSynced = false
        try? modelContext.save()
    }
}

// MARK: - Cards

struct DomainNodeCard: View {
    @Environment(\.modelContext) private var modelContext

    let node: Node
    let domainTitle: String
    var onOpen: () -> Void
    var onEdit: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(SymphoTheme.primaryCanvas)
                            .frame(width: 40, height: 40)
                        Image(systemName: DomainNodeVisuals.statusIcon(node.status))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(DomainNodeVisuals.statusColor(node.status))
                    }
                    .overlay {
                        Circle()
                            .stroke(DomainNodeVisuals.statusColor(node.status).opacity(0.35), lineWidth: 2)
                    }

                    Spacer(minLength: 0)
                }

                Text(node.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Image(systemName: DomainNodeGrouping.contextIcon(for: node))
                        .font(.system(size: 10, weight: .semibold))
                    Text(DomainNodeGrouping.contextLabel(for: node, domainTitle: domainTitle))
                        .lineLimit(1)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SymphoTheme.tertiaryText)

                HStack(spacing: 6) {
                    Text(node.status.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DomainNodeVisuals.statusColor(node.status))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DomainNodeVisuals.statusColor(node.status).opacity(0.12), in: .capsule)

                    if node.priority == .critical {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(SymphoTheme.colorCritical)
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            SymphoOverflowMenu(onEdit: onEdit, onDelete: { softDeleteNode() })
                .padding(8)
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SymphoTheme.elevatedCanvas.opacity(isHovering ? 0.9 : 0.58))
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DomainNodeVisuals.statusColor(node.status).opacity(0.7))
                .frame(width: 3)
                .padding(.vertical, 12)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isHovering ? SymphoTheme.primaryText.opacity(0.14) : SymphoTheme.dividerColor, lineWidth: 1)
        }
        .onHover { isHovering = $0 }
        .symphoCardContextMenu(edit: onEdit, delete: { softDeleteNode() })
    }

    private func softDeleteNode() {
        node.isDeletedLocally = true
        node.isSynced = false
        node.updatedAt = Date()
        try? modelContext.save()
    }
}

private struct DomainNodeKanbanCard: View {
    @Environment(\.modelContext) private var modelContext

    let node: Node
    let domainTitle: String
    var onOpen: () -> Void
    var onEdit: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: DomainNodeGrouping.contextIcon(for: node))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .frame(width: 22, height: 22)
                    .background(SymphoTheme.primaryCanvas.opacity(0.8), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                Spacer(minLength: 0)

                SymphoOverflowMenu(onEdit: onEdit, onDelete: { softDeleteNode() })
                    .scaleEffect(0.9)
            }

            Button(action: onOpen) {
                Text(node.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Text(DomainNodeGrouping.contextLabel(for: node, domainTitle: domainTitle))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(SymphoTheme.tertiaryText)
                .lineLimit(1)

            if node.priority == .critical {
                Label("Critical", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(SymphoTheme.colorCritical)
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SymphoTheme.primaryCanvas.opacity(isHovering ? 0.95 : 0.82))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(SymphoTheme.dividerColor.opacity(0.9), lineWidth: 1)
        }
        .onHover { isHovering = $0 }
        .symphoCardContextMenu(edit: onEdit, delete: { softDeleteNode() })
    }

    private func softDeleteNode() {
        node.isDeletedLocally = true
        node.isSynced = false
        node.updatedAt = Date()
        try? modelContext.save()
    }
}

// MARK: - Kanban drop

#if os(macOS)
private struct NodeKanbanColumnDropDelegate: DropDelegate {
    let targetStatus: NodeStatus
    @Binding var draggedNodeID: UUID?
    let onAssign: (UUID, NodeStatus) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedNodeID else { return }
        onAssign(draggedNodeID, targetStatus)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedNodeID = nil
        return true
    }
}
#endif

// MARK: - Types

private enum DomainNodesViewMode {
    case cards
    case kanban
}

private enum DomainNodesSort: String, CaseIterable, Identifiable {
    case updated
    case title
    case status
    case module

    var id: String { rawValue }

    var title: String {
        switch self {
        case .updated: return "Recently updated"
        case .title: return "Title A–Z"
        case .status: return "Status"
        case .module: return "Module"
        }
    }

    var shortTitle: String {
        switch self {
        case .updated: return "Updated"
        case .title: return "Title"
        case .status: return "Status"
        case .module: return "Module"
        }
    }

    var iconName: String {
        switch self {
        case .updated: return "clock"
        case .title: return "textformat"
        case .status: return "circle.hexagonpath"
        case .module: return "square.stack.3d.up"
        }
    }
}

private enum DomainNodesGroup: String, CaseIterable, Identifiable {
    case none
    case module
    case track

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "No grouping"
        case .module: return "By module"
        case .track: return "By track"
        }
    }

    var shortTitle: String {
        switch self {
        case .none: return "Group"
        case .module: return "Module"
        case .track: return "Track"
        }
    }

    var iconName: String {
        switch self {
        case .none: return "rectangle.3.group"
        case .module: return "square.stack.3d.up"
        case .track: return "point.topleft.down.curvedto.point.bottomright.up"
        }
    }
}

private enum DomainNodesStatusFilter: String, CaseIterable, Identifiable {
    case all
    case backlog
    case active
    case mastered

    var id: String { rawValue }

    var nodeStatus: NodeStatus? {
        switch self {
        case .all: return nil
        case .backlog: return .backlog
        case .active: return .active
        case .mastered: return .mastered
        }
    }

    var title: String {
        switch self {
        case .all: return "All statuses"
        case .backlog: return "Backlog"
        case .active: return "Active"
        case .mastered: return "Mastered"
        }
    }

    var iconName: String {
        switch self {
        case .all: return "line.3.horizontal.decrease.circle"
        case .backlog: return "circle"
        case .active: return "play.circle"
        case .mastered: return "checkmark.circle"
        }
    }
}

private struct DomainNodeSection: Identifiable {
    let id: String
    let title: String
    let iconName: String
    let nodes: [Node]
}

private enum DomainNodeGrouping {
    static func moduleKey(for node: Node) -> String {
        node.module?.id.uuidString ?? "orphan-module"
    }

    static func moduleTitle(for node: Node) -> String {
        node.module?.title ?? "No module"
    }

    static func trackKey(for node: Node) -> String {
        if let track = node.module?.track {
            return track.id.uuidString
        }
        return "standalone"
    }

    static func trackTitle(for node: Node) -> String {
        node.module?.track?.title ?? "Standalone"
    }

    static func contextLabel(for node: Node, domainTitle: String) -> String {
        if let project = node.project {
            return project.title
        }
        if let module = node.module {
            if let track = module.track {
                return "\(track.title) · \(module.title)"
            }
            return module.title
        }
        return domainTitle
    }

    static func contextIcon(for node: Node) -> String {
        if node.project != nil { return "folder" }
        if node.module?.track != nil { return "point.topleft.down.curvedto.point.bottomright.up" }
        if node.module != nil { return "square.stack.3d.up" }
        return "circle.hexagonpath"
    }
}

private enum DomainNodeVisuals {
    static func statusIcon(_ status: NodeStatus) -> String {
        switch status {
        case .backlog: return "circle.dashed"
        case .active: return "play.circle.fill"
        case .mastered: return "checkmark.circle.fill"
        }
    }

    static func statusColor(_ status: NodeStatus) -> Color {
        roadmapNodeColor(status)
    }
}
