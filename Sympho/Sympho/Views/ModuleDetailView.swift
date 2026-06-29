//
//  ModuleDetailView.swift
//  Sympho
//

import SwiftUI
import SwiftData

private enum ModuleWorkspaceSection: String, CaseIterable, Identifiable {
    case overview
    case nodes
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .nodes: return "Nodes"
        case .library: return "Library"
        }
    }

    var iconName: String {
        switch self {
        case .overview: return "sparkle"
        case .nodes: return "circle.hexagonpath"
        case .library: return "books.vertical"
        }
    }
}

struct ModuleDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let module: Module
    var backTitle: String = "Back"
    var onBack: () -> Void
    var onSelectNode: (Node) -> Void

    @State private var selectedSection: ModuleWorkspaceSection = .overview
    @State private var showsCompactTitle = false
    @State private var showsEditModuleSheet = false
    @State private var editNodeTarget: Node?

    private var moduleNodes: [Node] {
        module.activeNodes.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var primaryActiveNode: Node? {
        moduleNodes.first { $0.status == .active }
    }

    private var moduleSubtitle: String {
        if !module.desc.isEmpty { return module.desc }
        return "Learning nodes and materials for this module."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                scrollHeader
                workspaceTabBar
                    .padding(.bottom, selectedSection == .overview ? 12 : 20)

                Group {
                    switch selectedSection {
                    case .overview:
                        overviewContent
                    case .nodes:
                        nodesContent
                    case .library:
                        libraryContent
                    }
                }
            }
            .padding(.bottom, SymphoTheme.outerPadding)
        }
        .moduleScrollChrome(title: module.title, showsCompactTitle: $showsCompactTitle)
        .sheet(isPresented: $showsEditModuleSheet) {
            SymphoItemEditSheet(subject: .module(module)) {
                showsEditModuleSheet = false
            }
        }
        .sheet(item: $editNodeTarget) { node in
            SymphoItemEditSheet(subject: .node(node)) {
                editNodeTarget = nil
            }
        }
    }

    // MARK: - Header

    private var scrollHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            SymphoGlassBackButton(title: backTitle, action: onBack)

            HStack(alignment: .top, spacing: 14) {
                SymphoGlyphView(emoji: module.emoji, iconName: module.iconName,
                                fallbackSystemName: "square.stack.3d.up", size: 22)
                    .foregroundStyle(SymphoTheme.primaryText)
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text(module.title)
                        .editorialHeader()

                    Text(moduleSubtitle)
                        .metadataSans()
                        .fixedSize(horizontal: false, vertical: true)

                    moduleProgressStrip
                }

                Spacer(minLength: 0)

                SymphoOverflowMenu(
                    onEdit: { showsEditModuleSheet = true },
                    onDelete: { deleteModule() }
                )
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var moduleProgressStrip: some View {
        HStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(SymphoTheme.dividerColor.opacity(0.55))
                    Capsule()
                        .fill(SymphoTheme.primaryText.opacity(0.82))
                        .frame(width: max(4, proxy.size.width * module.progress))
                }
            }
            .frame(height: 4)
            .frame(maxWidth: 120)

            Text("\(Int(module.progress * 100))% mastered")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SymphoTheme.tertiaryText)
        }
        .padding(.top, 4)
    }

    private var workspaceTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ModuleWorkspaceSection.allCases) { section in
                    moduleTabChip(section)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, SymphoTheme.outerPadding - 4)
    }

    private func moduleTabChip(_ section: ModuleWorkspaceSection) -> some View {
        let isSelected = selectedSection == section

        return Button {
            withAnimation(.snappy(duration: 0.18)) {
                selectedSection = section
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: section.iconName)
                    .font(.system(size: 12, weight: .semibold))
                Text(section.title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(isSelected ? SymphoTheme.primaryCanvas : SymphoTheme.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule().fill(SymphoTheme.primaryText)
                } else {
                    Capsule().fill(SymphoTheme.elevatedCanvas.opacity(0.55))
                }
            }
            .overlay {
                Capsule()
                    .stroke(isSelected ? .clear : SymphoTheme.dividerColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Overview

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            overviewStatsRow
            overviewActiveSection
            overviewNodesPreview
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
    }

    private var overviewStatsRow: some View {
        HStack(spacing: 10) {
            overviewStatChip(section: .nodes, value: moduleNodes.count)
            overviewStatChip(section: .library, value: module.allResources.count, showsLibraryBadge: true)
        }
    }

    private func overviewStatChip(
        section: ModuleWorkspaceSection,
        value: Int,
        showsLibraryBadge: Bool = false
    ) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) {
                selectedSection = section
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: section.iconName)
                        .font(.system(size: 11, weight: .semibold))
                    if showsLibraryBadge {
                        Image(systemName: "building.columns")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(SymphoTheme.tertiaryText)
                    }
                }
                .foregroundStyle(SymphoTheme.secondaryText)

                Text("\(value)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)

                Text(section.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .trackWorkspaceSurface()
        }
        .buttonStyle(.plain)
    }

    private var overviewActiveSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("In motion")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SymphoTheme.primaryText)

            if let node = primaryActiveNode {
                Button { onSelectNode(node) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(SymphoTheme.colorActive)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(node.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(SymphoTheme.primaryText)
                                .lineLimit(1)
                            Text(nodeStatusLabel(node.status))
                                .font(.system(size: 11))
                                .foregroundStyle(SymphoTheme.secondaryText)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(SymphoTheme.tertiaryText)
                    }
                }
                .buttonStyle(.plain)
                .padding(12)
                .trackWorkspaceSurface()
            } else {
                Text("No active node — mark one Active in Nodes.")
                    .font(.system(size: 12))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .padding(12)
                    .trackWorkspaceSurface()
            }
        }
    }

    private var overviewNodesPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Nodes")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if moduleNodes.count > 5 {
                    Button("See all") {
                        selectedSection = .nodes
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .buttonStyle(.plain)
                }
            }

            if moduleNodes.isEmpty {
                Text("No nodes yet. Tap + on the Nodes tab.")
                    .captionSans()
            } else {
                VStack(spacing: 0) {
                    ForEach(moduleNodes.prefix(5)) { node in
                        Button { onSelectNode(node) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: nodeStatusIcon(node.status))
                                    .font(.system(size: 12))
                                    .foregroundStyle(nodeStatusColor(node.status))
                                Text(node.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(SymphoTheme.primaryText)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                if node.priority == .critical {
                                    Text("Critical")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(SymphoTheme.colorCritical)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(SymphoTheme.tertiaryText)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if node.id != moduleNodes.prefix(5).last?.id {
                            Rectangle()
                                .fill(SymphoTheme.dividerColor)
                                .frame(height: 1)
                                .padding(.leading, 12)
                        }
                    }
                }
                .trackWorkspaceSurface()
            }
        }
    }

    // MARK: - Nodes

    private var nodesContent: some View {
        Group {
            if let domain = module.resolvedDomain {
                DomainNodesWorkspaceView(
                    domain: domain,
                    nodes: moduleNodes,
                    module: module,
                    onSelectNode: onSelectNode,
                    onEditNode: { editNodeTarget = $0 }
                )
            } else {
                Text("This module has no domain context.")
                    .captionSans()
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
    }

    // MARK: - Library

    private var libraryContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Local library")
                            .editorialSubtitle()
                        Text("MODULE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(SymphoTheme.tertiaryText)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(SymphoTheme.elevatedCanvas, in: .capsule)
                    }
                    Text("PDFs, links, and files attached to nodes in this module.")
                        .captionSans()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            let resources = module.allResources
            if resources.isEmpty {
                VStack(spacing: 8) {
                    Text("Nothing attached yet.")
                        .font(.system(size: 13))
                        .foregroundStyle(SymphoTheme.secondaryText)
                    Text("Open a node and add materials to see them here.")
                        .captionSans()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .trackWorkspaceSurface()
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                    ForEach(resources) { res in
                        moduleResourceCard(res)
                    }
                }
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
    }

    private func moduleResourceCard(_ res: Resource) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: res.resourceType.iconName)
                    .foregroundStyle(SymphoTheme.secondaryText)
                Text(res.resourceType.displayName.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(SymphoTheme.secondaryText)
                Spacer()
            }
            Text(res.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SymphoTheme.primaryText)
                .lineLimit(2)
            let nodesText = res.nodes.filter { !$0.isDeletedLocally }.map(\.title).joined(separator: ", ")
            if !nodesText.isEmpty {
                Text("Linked: \(nodesText)")
                    .font(.system(size: 10))
                    .foregroundStyle(SymphoTheme.tertiaryText)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .trackWorkspaceSurface()
    }

    // MARK: - Helpers

    private var parentPageTitle: String {
        if let track = module.track {
            return track.title
        }
        if let domain = module.domain {
            return domain.title
        }
        return "Back"
    }

    private func deleteModule() {
        module.isDeletedLocally = true
        module.isSynced = false
        module.updatedAt = Date()
        try? modelContext.save()
        onBack()
    }

    private func nodeStatusIcon(_ status: NodeStatus) -> String {
        switch status {
        case .backlog: return "circle"
        case .active: return "play.circle.fill"
        case .mastered: return "checkmark.circle.fill"
        }
    }

    private func nodeStatusColor(_ status: NodeStatus) -> Color {
        switch status {
        case .backlog: return SymphoTheme.secondaryText
        case .active: return SymphoTheme.colorActive
        case .mastered: return SymphoTheme.colorMastered
        }
    }

    private func nodeStatusLabel(_ status: NodeStatus) -> String {
        switch status {
        case .backlog: return "Backlog"
        case .active: return "Active"
        case .mastered: return "Mastered"
        }
    }
}

// MARK: - Scroll chrome

private struct ModuleScrollChrome: ViewModifier {
    let title: String
    @Binding var showsCompactTitle: Bool

    func body(content: Content) -> some View {
        content
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 28
            } action: { _, newValue in
                withAnimation(.easeInOut(duration: 0.16)) {
                    showsCompactTitle = newValue
                }
            }
            .safeAreaBar(edge: .top, spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(1)
                    .opacity(showsCompactTitle ? 1 : 0)
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
                    .offset(y: -2)
                    .accessibilityHidden(!showsCompactTitle)
            }
    }
}

private extension View {
    func moduleScrollChrome(title: String, showsCompactTitle: Binding<Bool>) -> some View {
        modifier(ModuleScrollChrome(title: title, showsCompactTitle: showsCompactTitle))
    }
}
