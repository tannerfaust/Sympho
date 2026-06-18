//
//  TrackDetailView.swift
//  Sympho
//

import SwiftUI
import SwiftData

private enum TrackWorkspaceSection: String, CaseIterable, Identifiable {
    case overview
    case modules
    case nodes
    case projects
    case library
    case roadmap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .modules: return "Modules"
        case .nodes: return "Nodes"
        case .projects: return "Projects"
        case .library: return "Library"
        case .roadmap: return "Roadmap"
        }
    }

    var iconName: String {
        switch self {
        case .overview: return "sparkle"
        case .modules: return "square.stack.3d.up"
        case .nodes: return "circle.hexagonpath"
        case .projects: return "folder"
        case .library: return "books.vertical"
        case .roadmap: return "map"
        }
    }
}

struct TrackDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let track: Track
    var backTitle: String = "Domain"
    var onBack: () -> Void
    var onSelectModule: (Module) -> Void
    var onSelectNode: (Node) -> Void
    var onSelectProject: (Project) -> Void

    @State private var selectedSection: TrackWorkspaceSection = .overview
    @State private var showsCompactTitle = false
    @State private var showsEditTrackSheet = false
    @State private var editNodeTarget: Node?

    private var trackNodes: [Node] {
        track.allNodes.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var primaryActiveNode: Node? {
        trackNodes.first { $0.status == .active }
    }

    private var trackSubtitle: String {
        if !track.desc.isEmpty { return track.desc }
        return "Your path through modules, nodes, and projects."
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
                    case .modules:
                        modulesContent
                    case .nodes:
                        nodesContent
                    case .projects:
                        projectsContent
                    case .library:
                        libraryContent
                    case .roadmap:
                        roadmapContent
                    }
                }
            }
            .padding(.bottom, SymphoTheme.outerPadding)
        }
        .trackScrollChrome(title: track.title, showsCompactTitle: $showsCompactTitle)
        .sheet(isPresented: $showsEditTrackSheet) {
            SymphoItemEditSheet(subject: .track(track)) {
                showsEditTrackSheet = false
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
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .editorialHeader()

                    Text(trackSubtitle)
                        .metadataSans()
                        .fixedSize(horizontal: false, vertical: true)

                    trackProgressStrip
                }

                Spacer(minLength: 0)

                SymphoOverflowMenu(
                    onEdit: { showsEditTrackSheet = true },
                    onDelete: { deleteTrack() }
                )
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var trackProgressStrip: some View {
        HStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(SymphoTheme.dividerColor.opacity(0.55))
                    Capsule()
                        .fill(SymphoTheme.primaryText.opacity(0.82))
                        .frame(width: max(4, proxy.size.width * track.progress))
                }
            }
            .frame(height: 4)
            .frame(maxWidth: 120)

            Text("\(Int(track.progress * 100))% mastered")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SymphoTheme.tertiaryText)
        }
        .padding(.top, 4)
    }

    private var workspaceTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TrackWorkspaceSection.allCases) { section in
                    trackTabChip(section)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, SymphoTheme.outerPadding - 4)
    }

    private func trackTabChip(_ section: TrackWorkspaceSection) -> some View {
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
            overviewModulesPreview
            if !track.activeProjects.isEmpty {
                overviewProjectsStrip
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
    }

    private var overviewStatsRow: some View {
        HStack(spacing: 10) {
            overviewStatChip(section: .modules, value: track.activeModules.count)
            overviewStatChip(section: .nodes, value: trackNodes.count)
            overviewStatChip(section: .projects, value: track.activeProjects.count)
            overviewStatChip(section: .library, value: track.allResources.count, showsLibraryBadge: true)
        }
    }

    private func overviewStatChip(section: TrackWorkspaceSection, value: Int, showsLibraryBadge: Bool = false) -> some View {
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
                            Text(activeNodeContext(node))
                                .font(.system(size: 11))
                                .foregroundStyle(SymphoTheme.secondaryText)
                                .lineLimit(1)
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
                Text("No active node — pick one in Nodes when you're ready.")
                    .font(.system(size: 12))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .padding(12)
                    .trackWorkspaceSurface()
            }
        }
    }

    private var overviewModulesPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Modules")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if track.activeModules.count > 4 {
                    Button("See all") {
                        selectedSection = .modules
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .buttonStyle(.plain)
                }
            }

            if track.activeModules.isEmpty {
                Text("Add modules with + on the Modules tab.")
                    .captionSans()
            } else {
                VStack(spacing: 0) {
                    ForEach(track.activeModules.prefix(4)) { module in
                        Button { onSelectModule(module) } label: {
                            HStack {
                                Text(module.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(SymphoTheme.primaryText)
                                Spacer()
                                Text("\(module.nodes.filter { !$0.isDeletedLocally }.count) nodes")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(SymphoTheme.tertiaryText)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(SymphoTheme.tertiaryText)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        if module.id != track.activeModules.prefix(4).last?.id {
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

    private var overviewProjectsStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Projects")
                .font(.system(size: 12, weight: .semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(track.activeProjects) { project in
                        Button { onSelectProject(project) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(SymphoTheme.primaryText)
                                    .lineLimit(1)
                                Text(project.status.displayName)
                                    .font(.system(size: 10))
                                    .foregroundStyle(SymphoTheme.secondaryText)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .trackWorkspaceSurface()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var modulesContent: some View {
        TrackModulesWorkspaceView(
            track: track,
            onSelectModule: onSelectModule,
            onSelectNode: onSelectNode
        )
        .padding(.horizontal, SymphoTheme.outerPadding)
    }

    private var nodesContent: some View {
        Group {
            if let domain = track.domain {
                DomainNodesWorkspaceView(
                    domain: domain,
                    nodes: trackNodes,
                    track: track,
                    onSelectNode: onSelectNode,
                    onEditNode: { editNodeTarget = $0 }
                )
            } else {
                Text("This track has no domain context.")
                    .captionSans()
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
    }

    private var projectsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Projects in this track")
                .editorialSubtitle()

            if track.activeProjects.isEmpty {
                Text("No projects linked here yet.")
                    .captionSans()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
                    .trackWorkspaceSurface()
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                    ForEach(track.activeProjects) { project in
                        DomainProjectCard(project: project) {
                            onSelectProject(project)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
    }

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
                        Text("TRACK")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(SymphoTheme.tertiaryText)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(SymphoTheme.elevatedCanvas, in: .capsule)
                    }
                    Text("Assets from nodes and projects in this track — gathered here, not the global Library app section.")
                        .captionSans()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            let resources = track.allResources
            if resources.isEmpty {
                VStack(spacing: 8) {
                    Text("Nothing attached yet.")
                        .font(.system(size: 13))
                        .foregroundStyle(SymphoTheme.secondaryText)
                    Text("Link PDFs or URLs to nodes in this track to see them here.")
                        .captionSans()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .trackWorkspaceSurface()
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                    ForEach(resources) { res in
                        trackResourceCard(res)
                    }
                }
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
    }

    private func trackResourceCard(_ res: Resource) -> some View {
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

    private var roadmapContent: some View {
        TrackRoadmapView(track: track, onSelectModule: onSelectModule)
        .padding(.horizontal, SymphoTheme.outerPadding)
    }

    // MARK: - Helpers

    private func activeNodeContext(_ node: Node) -> String {
        if let module = node.module {
            return module.title
        }
        return track.title
    }

    private func deleteTrack() {
        track.isDeletedLocally = true
        track.isSynced = false
        track.updatedAt = Date()
        if let domain = track.domain {
            domain.isSynced = false
            domain.updatedAt = Date()
        }
        try? modelContext.save()
        onBack()
    }
}

// MARK: - Scroll chrome

private struct TrackScrollChrome: ViewModifier {
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
    func trackScrollChrome(title: String, showsCompactTitle: Binding<Bool>) -> some View {
        modifier(TrackScrollChrome(title: title, showsCompactTitle: showsCompactTitle))
    }
}
