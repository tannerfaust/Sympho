//
//  DomainsView.swift
//  Sympho
//
//  Created by Tanner Fause on 30.05.2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DomainsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigationContext.self) private var navigationContext
    
    @Query(
        filter: #Predicate<Domain> { !$0.isArchived && !$0.isDeletedLocally },
        sort: [SortDescriptor(\Domain.sortIndex), SortDescriptor(\Domain.title)]
    )
    private var domains: [Domain]
    
    @Binding var selectedDomain: Domain?
    @State private var showCreateDomainSheet = false
    @State private var draggedDomain: Domain?
    
    @State private var newDomainTitle = ""
    @State private var newDomainDesc = ""
    @State private var newDomainIcon: DomainIcon = .book
    
    @State private var selectedTrack: Track?
    @State private var selectedModule: Module?
    @State private var selectedNode: Node?
    @State private var selectedProject: Project?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let domain = selectedDomain {
                if let node = selectedNode {
                    NodeDetailView(node: node) {
                        selectedNode = nil
                    }
                } else if let project = selectedProject {
                    ProjectDetailView(project: project) {
                        selectedProject = nil
                    }
                } else if let module = selectedModule {
                    ModuleDetailView(module: module, onBack: {
                        selectedModule = nil
                    }, onSelectNode: { node in
                        selectedNode = node
                    })
                } else if let track = selectedTrack {
                    TrackDetailView(
                        track: track,
                        onBack: { selectedTrack = nil },
                        onSelectModule: { selectedModule = $0 },
                        onSelectNode: { selectedNode = $0 },
                        onSelectProject: { selectedProject = $0 }
                    )
                } else {
                    DomainDetailView(
                        domain: domain,
                        onBack: { selectedDomain = nil },
                        onSelectTrack: { track in selectedTrack = track },
                        onSelectModule: { module in selectedModule = module },
                        onSelectNode: { node in selectedNode = node },
                        onSelectProject: { project in selectedProject = project }
                    )
                }
            } else {
                domainsListView
            }
        }
        .onChange(of: selectedDomain) { _, _ in
            selectedTrack = nil
            selectedModule = nil
            selectedNode = nil
            selectedProject = nil
            syncNavigationContext()
        }
        .onChange(of: selectedTrack?.id) { _, _ in syncNavigationContext() }
        .onChange(of: selectedModule?.id) { _, _ in syncNavigationContext() }
        .onChange(of: selectedNode?.id) { _, _ in syncNavigationContext() }
        .onChange(of: selectedProject?.id) { _, _ in syncNavigationContext() }
        .onAppear {
            syncNavigationContext()
        }
    }

    private func syncNavigationContext() {
        navigationContext.updateDomainWorkspace(
            domain: selectedDomain,
            track: selectedTrack,
            module: selectedModule,
            node: selectedNode,
            project: selectedProject
        )
    }
    
    // MARK: - Domains Grid List
    
    private var domainsListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SymphoTheme.sectionSpacing) {
                HStack {
                    Text("My Domains")
                        .editorialHeader()

                    Spacer()

                    Button(action: { showCreateDomainSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .help("New Domain")
                    .accessibilityLabel("New Domain")
                }
                .padding(.top, 4)
                
                MinimalDivider()
                
                if domains.isEmpty {
                    emptyDomainsView
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: SymphoTheme.gridSpacing) {
                        ForEach(domains) { domain in
                            Button(action: {
                                selectedDomain = domain
                            }) {
                                DomainCard(domain: domain)
                            }
                            .buttonStyle(.plain)
                            #if os(macOS)
                            .onDrag {
                                draggedDomain = domain
                                return NSItemProvider(object: domain.id.uuidString as NSString)
                            }
                            .onDrop(
                                of: [UTType.text],
                                delegate: DomainDropDelegate(
                                    destination: domain,
                                    domains: domains,
                                    draggedDomain: $draggedDomain,
                                    onMove: persistDomainOrder
                                )
                            )
                            #endif
                        }
                    }
                }
            }
            .padding(SymphoTheme.outerPadding)
        }
        .sheet(isPresented: $showCreateDomainSheet) {
            createDomainSheet
        }
    }
    
    private var emptyDomainsView: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 80)
            Image(systemName: "map")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(SymphoTheme.secondaryText)
            Text("No study domains yet.")
                .font(.system(.headline, design: .default))
            Text("Define major fields (e.g. Computer Science, Philosophy) to map your tracks.")
                .metadataSans()
                .multilineTextAlignment(.center)
            Button("Add Your First Domain") {
                showCreateDomainSheet = true
            }
            .buttonStyle(SymphoPrimaryButtonStyle())
            .padding(.top, 12)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Create Domain Sheet
    
    private var createDomainSheet: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: newDomainIcon.rawValue)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular, in: .rect(cornerRadius: 15))

                VStack(alignment: .leading, spacing: 5) {
                    Text("Create a Domain")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(SymphoTheme.primaryText)

                    Text("Domains are long-lived areas of study. Give this one a clear name, a short description, and an icon you can recognize at a glance.")
                        .font(.system(size: 12))
                        .foregroundStyle(SymphoTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                DomainEditorField(title: "NAME") {
                    TextField("Machine Learning", text: $newDomainTitle)
                        .textFieldStyle(.plain)
                }

                DomainEditorField(title: "DESCRIPTION") {
                    TextField("What belongs in this domain?", text: $newDomainDesc, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(2...3)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("ICON")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SymphoTheme.tertiaryText)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                    ForEach(DomainIcon.allCases) { icon in
                        Button {
                            newDomainIcon = icon
                        } label: {
                            Image(systemName: icon.rawValue)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(SymphoTheme.primaryText)
                                .frame(width: 44, height: 36)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(newDomainIcon == icon ? SymphoTheme.elevatedCanvas : SymphoTheme.secondarySurface.opacity(0.5))
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(newDomainIcon == icon ? SymphoTheme.primaryText.opacity(0.24) : SymphoTheme.dividerColor, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .help(icon.displayName)
                    }
                }
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    resetDomainDraft()
                    showCreateDomainSheet = false
                }
                .buttonStyle(SymphoSecondaryButtonStyle())

                Button("Create Domain") {
                    let domain = Domain(
                        title: newDomainTitle,
                        desc: newDomainDesc,
                        iconName: newDomainIcon.rawValue,
                        sortIndex: domains.count
                    )
                    modelContext.insert(domain)
                    try? modelContext.save()
                    resetDomainDraft()
                    showCreateDomainSheet = false
                }
                .buttonStyle(SymphoPrimaryButtonStyle())
                .disabled(newDomainTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(22)
        .background(SymphoTheme.primaryCanvas)
        #if os(macOS)
        .frame(width: 470)
        #endif
    }

    private func resetDomainDraft() {
        newDomainTitle = ""
        newDomainDesc = ""
        newDomainIcon = .book
    }

    private func persistDomainOrder(_ reorderedDomains: [Domain]) {
        for (index, domain) in reorderedDomains.enumerated() {
            domain.sortIndex = index
            domain.isSynced = false
            domain.updatedAt = Date()
        }

        try? modelContext.save()
    }
}

// MARK: - Domain Card

struct DomainCard: View {
    @Environment(\.modelContext) private var modelContext
    let domain: Domain

    @State private var isHovering = false
    @State private var showsEditSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: DomainIcon.validated(domain.iconName))
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .frame(width: 46, height: 46)
                    .background {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(SymphoTheme.elevatedCanvas.opacity(0.76))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(domain.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(SymphoTheme.primaryText)
                        .lineLimit(2)

                    Text(domain.desc.isEmpty ? "A field for ongoing exploration." : domain.desc)
                        .font(.system(size: 12))
                        .foregroundColor(domain.desc.isEmpty ? SymphoTheme.tertiaryText : SymphoTheme.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let activeNode = latestActiveNode {
                    HStack(spacing: 5) {
                        Image(systemName: "scope")
                        Text("Current focus")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SymphoTheme.tertiaryText)

                    Text(activeNode.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .lineLimit(1)
                } else {
                    Text("No active focus")
                        .font(.system(size: 12))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                }
            }

            MinimalDivider()

            HStack(spacing: 12) {
                DomainCardMetric(iconName: "square.stack.3d.up", value: domain.tracks.filter { !$0.isDeletedLocally }.count)
                DomainCardMetric(iconName: "checklist", value: domain.allNodes.count)
                DomainCardMetric(iconName: "doc.text", value: domain.allResources.count)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SymphoTheme.elevatedCanvas.opacity(isHovering ? 0.86 : 0.66))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isHovering ? SymphoTheme.primaryText.opacity(0.18) : SymphoTheme.dividerColor, lineWidth: 1)
        }
        .shadow(color: .black.opacity(isHovering ? 0.075 : 0.035), radius: isHovering ? 12 : 7, y: 3)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Edit", systemImage: "pencil") { showsEditSheet = true }
            Button("Delete", role: .destructive, action: softDeleteDomain)
            Menu("Change Icon") {
                ForEach(DomainIcon.allCases) { icon in
                    Button {
                        domain.iconName = icon.rawValue
                        domain.isSynced = false
                        domain.updatedAt = Date()
                        try? modelContext.save()
                    } label: {
                        Label(icon.displayName, systemImage: icon.rawValue)
                    }
                }
            }
        }
        .sheet(isPresented: $showsEditSheet) {
            SymphoItemEditSheet(subject: .domain(domain)) {
                showsEditSheet = false
            }
        }
    }

    private func softDeleteDomain() {
        domain.isDeletedLocally = true
        domain.isSynced = false
        domain.updatedAt = Date()
        try? modelContext.save()
    }

    private var latestActiveNode: Node? {
        domain.allNodes
            .filter { $0.status == .active }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }
}

private struct DomainEditorField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SymphoTheme.tertiaryText)

            content
                .font(.system(size: 13))
                .foregroundStyle(SymphoTheme.primaryText)
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(SymphoTheme.elevatedCanvas.opacity(0.72))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                }
        }
    }
}

private struct DomainCardMetric: View {
    let iconName: String
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
            Text("\(value)")
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(SymphoTheme.secondaryText)
    }
}

#if os(macOS)
private struct DomainDropDelegate: DropDelegate {
    let destination: Domain
    let domains: [Domain]
    @Binding var draggedDomain: Domain?
    let onMove: ([Domain]) -> Void

    func dropEntered(info: DropInfo) {
        guard
            let draggedDomain,
            draggedDomain.id != destination.id,
            let sourceIndex = domains.firstIndex(where: { $0.id == draggedDomain.id }),
            let destinationIndex = domains.firstIndex(where: { $0.id == destination.id })
        else {
            return
        }

        var reordered = domains
        reordered.move(
            fromOffsets: IndexSet(integer: sourceIndex),
            toOffset: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
        )
        onMove(reordered)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedDomain = nil
        return true
    }
}
#endif

// MARK: - Domain Workspace

private enum DomainWorkspaceSection: String, CaseIterable, Identifiable {
    case overview
    case tracks
    case modules
    case nodes
    case projects
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .tracks: return "Tracks"
        case .modules: return "Modules"
        case .nodes: return "Nodes"
        case .projects: return "Projects"
        case .library: return "Library"
        }
    }

    var iconName: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .tracks: return "point.topleft.down.curvedto.point.bottomright.up"
        case .modules: return "square.stack.3d.up"
        case .nodes: return "circle.hexagonpath"
        case .projects: return "folder"
        case .library: return "books.vertical"
        }
    }
}

// MARK: - Domain Detail View (Nested)

struct DomainDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let domain: Domain
    var onBack: () -> Void
    var onSelectTrack: (Track) -> Void
    var onSelectModule: (Module) -> Void
    var onSelectNode: (Node) -> Void
    var onSelectProject: (Project) -> Void

    @State private var selectedSection: DomainWorkspaceSection = .overview

    @State private var showInlineAddTrack = false
    @State private var newTrackInlineTitle = ""

    @State private var showInlineAddModule = false
    @State private var newModuleInlineTitle = ""

    @State private var showInlineAddProject = false
    @State private var newProjectInlineTitle = ""

    @State private var showsCompactTitle = false
    @State private var showsEditDomainSheet = false
    @State private var editActiveNode = false
    @State private var editNodeTarget: Node?

    private var activeTracks: [Track] {
        domain.tracks.filter { !$0.isDeletedLocally }
    }

    private var activeStandaloneModules: [Module] {
        domain.modules.filter { !$0.isDeletedLocally && $0.track == nil }
    }

    private var allDomainModules: [Module] {
        let trackModules = activeTracks.flatMap { track in
            track.modules.filter { !$0.isDeletedLocally }
        }
        var seen = Set<UUID>()
        var combined: [Module] = []
        for module in activeStandaloneModules + trackModules {
            if seen.insert(module.id).inserted {
                combined.append(module)
            }
        }
        return combined
    }

    private var allDomainNodes: [Node] {
        domain.allNodes.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var activeProjects: [Project] {
        domain.projects.filter { !$0.isDeletedLocally }
    }

    /// Single active node for overview — most recently updated among `.active` nodes.
    private var primaryActiveNode: Node? {
        allDomainNodes
            .filter { $0.status == .active }
            .first
    }

    private var domainSubtitle: String {
        if !domain.desc.isEmpty {
            return domain.desc
        }
        return "Study workspace for tracks, modules, nodes, and projects."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                scrollHeader
                workspaceTabBar
                    .padding(.bottom, selectedSection == .overview ? 12 : 20)

                if selectedSection == .overview {
                    VStack(alignment: .leading, spacing: 20) {
                        activeSection
                        DomainRoadmapView(
                            domain: domain,
                            onSelectTrack: onSelectTrack,
                            onSelectModule: onSelectModule
                        )
                    }
                    .padding(.horizontal, SymphoTheme.outerPadding)
                    .padding(.bottom, 20)
                }

                Group {
                    switch selectedSection {
                    case .overview:
                        EmptyView()
                    case .tracks:
                        tracksContent
                    case .modules:
                        modulesContent
                    case .nodes:
                        nodesContent
                    case .projects:
                        projectsContent
                    case .library:
                        localLibraryContent
                    }
                }
            }
            .padding(.bottom, SymphoTheme.outerPadding)
        }
        .domainScrollChrome(title: domain.title, showsCompactTitle: $showsCompactTitle)
        .sheet(isPresented: $showsEditDomainSheet) {
            SymphoItemEditSheet(subject: .domain(domain)) {
                showsEditDomainSheet = false
            }
        }
        .sheet(isPresented: $editActiveNode) {
            if let node = primaryActiveNode {
                SymphoItemEditSheet(subject: .node(node)) {
                    editActiveNode = false
                }
            }
        }
        .sheet(item: $editNodeTarget) { node in
            SymphoItemEditSheet(subject: .node(node)) {
                editNodeTarget = nil
            }
        }
    }

    private var scrollHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help("Back to Domains")

            HStack(alignment: .top, spacing: 14) {
                Image(systemName: DomainIcon.validated(domain.iconName))
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text(domain.title)
                        .editorialHeader()

                    Text(domainSubtitle)
                        .metadataSans()
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                SymphoOverflowMenu(
                    onEdit: { showsEditDomainSheet = true },
                    onDelete: { deleteDomain() }
                )
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func deleteDomain() {
        domain.isDeletedLocally = true
        domain.isSynced = false
        domain.updatedAt = Date()
        try? modelContext.save()
        onBack()
    }

    private func deleteNode(_ node: Node) {
        node.isDeletedLocally = true
        node.isSynced = false
        node.updatedAt = Date()
        domain.updatedAt = Date()
        domain.isSynced = false
        try? modelContext.save()
    }

    private var workspaceTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DomainWorkspaceSection.allCases) { section in
                    domainWorkspaceTabChip(section)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, SymphoTheme.outerPadding - 4)
    }

    private func domainWorkspaceTabChip(_ section: DomainWorkspaceSection) -> some View {
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
                    Capsule()
                        .fill(SymphoTheme.primaryText)
                } else {
                    Capsule()
                        .fill(SymphoTheme.elevatedCanvas.opacity(0.55))
                }
            }
            .overlay {
                Capsule()
                    .stroke(isSelected ? .clear : SymphoTheme.dividerColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Overview (active only, directly under tabs)

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Active")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SymphoTheme.primaryText)

            if let node = primaryActiveNode {
                HStack(spacing: 10) {
                    Button {
                        onSelectNode(node)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "scope")
                                .font(.system(size: 14))
                                .foregroundStyle(SymphoTheme.colorActive)
                                .frame(width: 36, height: 36)
                                .glassEffect(.regular, in: .circle)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(node.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(SymphoTheme.primaryText)
                                    .lineLimit(1)

                                Text(activeNodeContext(for: node))
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

                    SymphoOverflowMenu(
                        onEdit: { editActiveNode = true },
                        onDelete: { deleteNode(node) }
                    )
                }
                .padding(12)
                .domainListSurface()
                .symphoCardContextMenu(
                    edit: { editActiveNode = true },
                    delete: { deleteNode(node) }
                )
            } else {
                Text("No active node. Mark one as Active in Nodes.")
                    .font(.system(size: 12))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .domainListSurface()
            }
        }
    }

    private func activeNodeContext(for node: Node) -> String {
        if let module = node.module {
            if let track = module.track {
                return "\(track.title) · \(module.title)"
            }
            return module.title
        }
        if let project = node.project {
            return "Project · \(project.title)"
        }
        return domain.title
    }

    // MARK: - Tracks

    private var tracksContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Tracks",
                showsAdd: true,
                addAction: { showInlineAddTrack.toggle() }
            )

            if showInlineAddTrack {
                inlineCreateField(
                    placeholder: "Track title…",
                    text: $newTrackInlineTitle,
                    onSave: saveTrackInline
                )
            }

            if activeTracks.isEmpty {
                emptySectionMessage("No tracks yet.")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
                    ForEach(activeTracks) { track in
                        DomainTrackCard(track: track) {
                            onSelectTrack(track)
                        } onSelectNode: { node in
                            onSelectNode(node)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
    }

    // MARK: - Modules

    private var modulesContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Modules",
                showsAdd: true,
                addAction: { showInlineAddModule.toggle() }
            )

            if showInlineAddModule {
                inlineCreateField(
                    placeholder: "Standalone module title…",
                    text: $newModuleInlineTitle,
                    onSave: saveStandaloneModuleInline
                )
            }

            if allDomainModules.isEmpty {
                emptySectionMessage("No modules yet.")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
                    ForEach(allDomainModules) { module in
                        DomainModuleCard(module: module) {
                            onSelectModule(module)
                        } onSelectNode: { node in
                            onSelectNode(node)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
    }

    // MARK: - Nodes

    private var nodesContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Nodes", showsAdd: false, addAction: {})

            LiquidGlassPromptBanner(
                domain: domain,
                onNodeCreated: { onSelectNode($0) }
            )

            DomainNodesWorkspaceView(
                domain: domain,
                nodes: allDomainNodes,
                onSelectNode: onSelectNode,
                onEditNode: { editNodeTarget = $0 }
            )
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
    }

    // MARK: - Projects

    private var projectsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Projects",
                subtitle: "Focused workspaces tied to this domain.",
                showsAdd: true,
                addAction: { showInlineAddProject.toggle() }
            )

            if showInlineAddProject {
                inlineCreateField(
                    placeholder: "Project title…",
                    text: $newProjectInlineTitle,
                    onSave: saveProjectInline
                )
            }

            if activeProjects.isEmpty {
                emptySectionMessage("No projects in this domain yet.")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                    ForEach(activeProjects) { project in
                        DomainProjectCard(project: project) {
                            onSelectProject(project)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
    }

    @ViewBuilder
    private func sectionHeader(
        title: String,
        subtitle: String? = nil,
        showsAdd: Bool,
        addAction: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .editorialSubtitle()
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .captionSans()
                }
            }

            Spacer(minLength: 0)

            if showsAdd {
                Button(action: {
                    withAnimation(.snappy(duration: 0.15)) {
                        addAction()
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
        }
    }

    private func inlineCreateField(
        placeholder: String,
        text: Binding<String>,
        onSave: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: text, onCommit: onSave)
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

            Button("Add", action: onSave)
                .buttonStyle(SymphoPrimaryButtonStyle())
        }
        .transition(.opacity)
    }

    private func emptySectionMessage(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(SymphoTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private func saveTrackInline() {
        let title = newTrackInlineTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        
        let nextIndex = activeTracks.map(\.sortIndex).max().map { $0 + 1 } ?? 0
        let newTrack = Track(title: title, desc: "", sortIndex: nextIndex, domain: domain)
        modelContext.insert(newTrack)
        domain.tracks.append(newTrack)
        domain.isSynced = false
        try? modelContext.save()
        
        newTrackInlineTitle = ""
        showInlineAddTrack = false
    }
    
    private func saveStandaloneModuleInline() {
        let title = newModuleInlineTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }

        let nextIndex = activeStandaloneModules.map(\.sortIndex).max().map { $0 + 1 } ?? 0
        let newModule = Module(title: title, desc: "", sortIndex: nextIndex, domain: domain)
        modelContext.insert(newModule)
        domain.modules.append(newModule)
        domain.isSynced = false
        try? modelContext.save()

        newModuleInlineTitle = ""
        showInlineAddModule = false
    }

    private func saveProjectInline() {
        let title = newProjectInlineTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let project = Project(title: title, desc: "", status: .active, domain: domain)
        modelContext.insert(project)
        domain.projects.append(project)
        domain.isSynced = false
        try? modelContext.save()

        newProjectInlineTitle = ""
        showInlineAddProject = false
    }

    // MARK: - Local Library

    private var localLibraryContent: some View {
        VStack(alignment: .leading, spacing: SymphoTheme.sectionSpacing) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Domain Assets")
                    .editorialSubtitle()
                Text("Reference material gathered from tracks, modules, and nodes in this domain.")
                    .captionSans()
            }

            let resources = domain.allResources
                if resources.isEmpty {
                    VStack(spacing: 8) {
                        Text("No assets attached inside this domain.")
                            .font(.system(.body, design: .default))
                            .foregroundColor(SymphoTheme.secondaryText)
                        Text("Link PDFs or web addresses to node learning units to see them gathered here.")
                            .captionSans()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
                    .premiumCard()
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260))], spacing: SymphoTheme.gridSpacing) {
                        ForEach(resources) { res in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: res.resourceType.iconName)
                                        .foregroundColor(SymphoTheme.secondaryText)
                                    Text(res.resourceType.displayName.uppercased())
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(SymphoTheme.secondaryText)
                                    Spacer()
                                }
                                
                                Text(res.title)
                                    .font(.system(.headline, design: .default))
                                    .foregroundColor(SymphoTheme.primaryText)
                                    .lineLimit(1)
                                
                                if !res.attachments.isEmpty || res.fileRelativePath != nil {
                                    Label("\(max(res.attachments.count, 1)) attached file\(max(res.attachments.count, 1) == 1 ? "" : "s")", systemImage: "paperclip")
                                        .font(.caption)
                                        .foregroundColor(SymphoTheme.secondaryText)
                                } else if let url = URL(string: res.urlString), !url.isFileURL {
                                    Link(res.urlString, destination: url)
                                        .font(.caption)
                                        .foregroundColor(SymphoTheme.colorActive)
                                        .lineLimit(1)
                                } else if !res.urlString.isEmpty {
                                    Text(res.urlString)
                                        .font(.caption)
                                        .foregroundColor(SymphoTheme.secondaryText)
                                        .lineLimit(1)
                                }
                                
                                // Linked nodes indicator
                                let nodesText = res.nodes.filter { !$0.isDeletedLocally }.map(\.title).joined(separator: ", ")
                                if !nodesText.isEmpty {
                                    Text("Linked to: \(nodesText)")
                                        .font(.system(size: 10))
                                        .foregroundColor(SymphoTheme.secondaryText)
                                        .lineLimit(1)
                                        .padding(.top, 4)
                                }
                            }
                            .premiumCard()
                        }
                    }
                }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
    }
}

struct DomainProjectCard: View {
    @Environment(\.modelContext) private var modelContext

    let project: Project
    let onOpen: () -> Void

    @State private var isHovering = false
    @State private var showsEditSheet = false

    private var activeNodes: [Node] {
        project.nodes.filter { !$0.isDeletedLocally }
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "folder")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .frame(width: 42, height: 42)
                        .glassEffect(.regular, in: .rect(cornerRadius: 13))

                    Spacer()

                    Text(project.status.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SymphoTheme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(SymphoTheme.elevatedCanvas.opacity(0.8), in: .capsule)
                }

                Text(project.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(project.desc.isEmpty ? "Domain project workspace" : project.desc)
                    .font(.system(size: 11))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .lineLimit(2)
                    .frame(minHeight: 28, alignment: .topLeading)

                Label("\(activeNodes.count) nodes", systemImage: "checklist")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SymphoTheme.elevatedCanvas.opacity(isHovering ? 0.88 : 0.64))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isHovering ? SymphoTheme.primaryText.opacity(0.14) : SymphoTheme.dividerColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .symphoCardContextMenu(
            edit: { showsEditSheet = true },
            delete: { softDeleteProject() }
        )
        .sheet(isPresented: $showsEditSheet) {
            SymphoItemEditSheet(subject: .project(project)) {
                showsEditSheet = false
            }
        }
    }

    private func softDeleteProject() {
        project.isDeletedLocally = true
        project.isSynced = false
        project.updatedAt = Date()
        try? modelContext.save()
    }
}

private extension View {
    func domainListSurface() -> some View {
        background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SymphoTheme.elevatedCanvas.opacity(0.56))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        }
    }
}

private struct DomainScrollChrome: ViewModifier {
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
    func domainScrollChrome(title: String, showsCompactTitle: Binding<Bool>) -> some View {
        modifier(DomainScrollChrome(title: title, showsCompactTitle: showsCompactTitle))
    }
}

private struct WorkspaceFact: View {
    let iconName: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
            Text(text)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(SymphoTheme.secondaryText)
    }
}

// MARK: - Curriculum Cards

struct DomainTrackCard: View {
    @Environment(\.modelContext) private var modelContext
    let track: Track
    var onSelect: () -> Void
    var onSelectNode: (Node) -> Void

    @State private var isHovering = false
    @State private var showsEditSheet = false

    private var activeModules: [Module] {
        track.modules.filter { !$0.isDeletedLocally }
    }

    private var nodeCount: Int {
        track.allNodes.count
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .frame(width: 52, height: 52)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 5) {
                        Text("TRACK")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(SymphoTheme.tertiaryText)
                            .tracking(0.6)

                        Text(track.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(SymphoTheme.primaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if !track.desc.isEmpty {
                            Text(track.desc)
                                .font(.system(size: 12))
                                .foregroundStyle(SymphoTheme.secondaryText)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 14) {
                    Label("\(activeModules.count) modules", systemImage: "square.stack.3d.up")
                    Label("\(nodeCount) nodes", systemImage: "checklist")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SymphoTheme.secondaryText)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Progress")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(SymphoTheme.tertiaryText)
                        Spacer()
                        Text("\(Int(track.progress * 100))%")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(SymphoTheme.secondaryText)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(SymphoTheme.dividerColor.opacity(0.55))
                            Capsule()
                                .fill(SymphoTheme.primaryText.opacity(0.82))
                                .frame(width: max(6, proxy.size.width * track.progress))
                        }
                    }
                    .frame(height: 5)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SymphoTheme.elevatedCanvas.opacity(isHovering ? 0.88 : 0.64))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isHovering ? SymphoTheme.primaryText.opacity(0.14) : SymphoTheme.dividerColor,
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(isHovering ? 0.07 : 0.03), radius: isHovering ? 14 : 8, y: 4)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .symphoCardContextMenu(
            edit: { showsEditSheet = true },
            delete: { softDeleteTrack() }
        )
        .sheet(isPresented: $showsEditSheet) {
            SymphoItemEditSheet(subject: .track(track)) {
                showsEditSheet = false
            }
        }
    }

    private func softDeleteTrack() {
        track.isDeletedLocally = true
        track.isSynced = false
        track.updatedAt = Date()
        try? modelContext.save()
    }
}

struct DomainModuleCard: View {
    @Environment(\.modelContext) private var modelContext
    let module: Module
    var onSelect: () -> Void
    var onSelectNode: (Node) -> Void

    @State private var isHovering = false
    @State private var showsEditSheet = false
    @State private var editNodeTarget: Node?

    private var sortedNodes: [Node] {
        module.nodes.filter { !$0.isDeletedLocally }.roadmapSorted()
    }

    private var progress: Double {
        guard !sortedNodes.isEmpty else { return 0 }
        let mastered = sortedNodes.filter { $0.status == .mastered }.count
        return Double(mastered) / Double(sortedNodes.count)
    }

    private var parentTrackTitle: String? {
        guard let track = module.track, !track.isDeletedLocally else { return nil }
        return track.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 12) {
                    moduleGlyph

                    VStack(alignment: .leading, spacing: 6) {
                        Text(module.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(SymphoTheme.primaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 8) {
                            if let parentTrackTitle {
                                Label(parentTrackTitle, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                            } else {
                                Label("Standalone", systemImage: "square.stack.3d.up")
                            }
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                        .lineLimit(1)

                        if !module.desc.isEmpty {
                            Text(module.desc)
                                .font(.system(size: 12))
                                .foregroundStyle(SymphoTheme.secondaryText)
                                .lineLimit(2)
                        }

                        moduleProgressStrip
                    }

                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if !sortedNodes.isEmpty {
                Rectangle()
                    .fill(SymphoTheme.dividerColor.opacity(0.65))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    ForEach(Array(sortedNodes.prefix(4).enumerated()), id: \.element.id) { index, node in
                        moduleNodeRow(node)

                        if index < min(sortedNodes.count, 4) - 1 {
                            MinimalDivider()
                                .padding(.leading, 34)
                        }
                    }

                    if sortedNodes.count > 4 {
                        Button(action: onSelect) {
                            Text("+\(sortedNodes.count - 4) more")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(SymphoTheme.tertiaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                                .padding(.leading, 34)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SymphoTheme.elevatedCanvas.opacity(isHovering ? 0.9 : 0.58))
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(moduleAccentGradient)
                .frame(width: 4)
                .padding(.vertical, 14)
                .padding(.leading, 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isHovering ? SymphoTheme.primaryText.opacity(0.14) : SymphoTheme.dividerColor,
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(isHovering ? 0.06 : 0.03), radius: isHovering ? 12 : 8, y: 3)
        .onHover { isHovering = $0 }
        .symphoCardContextMenu(
            edit: { showsEditSheet = true },
            delete: { softDeleteModule() }
        )
        .sheet(isPresented: $showsEditSheet) {
            SymphoItemEditSheet(subject: .module(module)) {
                showsEditSheet = false
            }
        }
        .sheet(item: $editNodeTarget) { node in
            SymphoItemEditSheet(subject: .node(node)) {
                editNodeTarget = nil
            }
        }
    }

    private func softDeleteModule() {
        module.isDeletedLocally = true
        module.isSynced = false
        module.updatedAt = Date()
        try? modelContext.save()
    }

    private func softDeleteNode(_ node: Node) {
        node.isDeletedLocally = true
        node.isSynced = false
        node.updatedAt = Date()
        try? modelContext.save()
    }

    private var moduleGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SymphoTheme.primaryCanvas.opacity(0.85))
                .frame(width: 48, height: 48)

            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(SymphoTheme.primaryText.opacity(0.88))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        }
    }

    private var moduleAccentGradient: LinearGradient {
        LinearGradient(
            colors: [
                SymphoTheme.colorMastered.opacity(0.55),
                SymphoTheme.primaryText.opacity(0.2)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var moduleProgressStrip: some View {
        HStack(spacing: 10) {
            Text("\(sortedNodes.count) nodes")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SymphoTheme.secondaryText)

            if !sortedNodes.isEmpty {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(SymphoTheme.dividerColor.opacity(0.5))
                        Capsule()
                            .fill(SymphoTheme.colorMastered.opacity(0.85))
                            .frame(width: max(4, proxy.size.width * progress))
                    }
                }
                .frame(height: 4)
                .frame(maxWidth: 72)

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }
        }
    }

    private func moduleNodeRow(_ node: Node) -> some View {
        Button(action: { onSelectNode(node) }) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(nodeStatusColor(node.status).opacity(0.35), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    Circle()
                        .fill(nodeStatusColor(node.status))
                        .frame(width: 8, height: 8)
                }

                Text(node.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if node.priority == .critical {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(SymphoTheme.colorCritical)
                }

                Text(node.status.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit", systemImage: "pencil") { editNodeTarget = node }
            Button("Delete", role: .destructive) { softDeleteNode(node) }
        }
    }

    private func nodeStatusColor(_ status: NodeStatus) -> Color {
        switch status {
        case .backlog: return SymphoTheme.secondaryText
        case .active: return SymphoTheme.colorActive
        case .mastered: return SymphoTheme.colorMastered
        }
    }
}
