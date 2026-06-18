//
//  NavigationShell.swift
//  Sympho
//
//  Created by Tanner Fause on 30.05.2026.
//

import SwiftUI
import SwiftData

enum NavSection: String, CaseIterable, Identifiable {
    case dashboard
    case inbox
    case domains
    case projects
    case readingList
    case planner
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Home"
        case .inbox: return "Inbox"
        case .domains: return "Domains"
        case .projects: return "Projects"
        case .readingList: return "Reading List"
        case .planner: return "Planner"
        case .library: return "Library"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard: return "Active focus and queue"
        case .inbox: return "Unsorted captures"
        case .domains: return "Fields of study"
        case .projects: return "Output workspaces"
        case .readingList: return "Books you are reading"
        case .planner: return "Study & training rhythm"
        case .library: return "Reference material"
        }
    }

    var iconName: String {
        switch self {
        case .dashboard: return "sparkle.magnifyingglass"
        case .inbox: return "tray"
        case .domains: return "books.vertical"
        case .projects: return "folder"
        case .readingList: return "book.closed.fill"
        case .planner: return "calendar.badge.clock"
        case .library: return "books.vertical"
        }
    }

    var shortcut: KeyEquivalent {
        switch self {
        case .dashboard: return "1"
        case .inbox: return "2"
        case .domains: return "3"
        case .projects: return "4"
        case .readingList: return "5"
        case .planner: return "6"
        case .library: return "7"
        }
    }
}

struct NavigationShell: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigationContext.self) private var navigationContext
    @AppStorage("devCaptureEnabled") private var devCaptureEnabled = DevCaptureSettings.isEnabled
    @State private var selectedSection: NavSection = .dashboard
    @State private var selectedDomain: Domain?
    @State private var selectedTrack: Track?
    @State private var selectedModule: Module?
    @State private var selectedProject: Project?
    @State private var expandedDomainIDs: Set<UUID> = []
    @State private var expandedTrackIDs: Set<UUID> = []
    @State private var showQuickCapture = false
    @State private var showDevCapture = false
    @State private var showGlobalSearch = false
    @State private var selectedSearchNode: Node?
    @State private var librarySearchText = ""
    @State private var libraryOpenResourceID: UUID?
    @State private var libraryOpenTagID: UUID?
    @State private var projectsOpenProjectID: UUID?
    @State private var domainsPendingNodeID: UUID?
    @State private var isShowingSettings = false

    @Query(
        filter: #Predicate<Domain> { !$0.isArchived && !$0.isDeletedLocally },
        sort: [SortDescriptor(\Domain.sortIndex), SortDescriptor(\Domain.title)]
    )
    private var domains: [Domain]

    var syncManager = SyncManager.shared

    var body: some View {
        Group {
            #if os(macOS)
            macOSLayout
            #else
            iOSLayout
            #endif
        }
        .sheet(isPresented: $showQuickCapture) {
            QuickCaptureOverlay(isPresented: $showQuickCapture)
        }
        .sheet(isPresented: $showDevCapture) {
            DevCaptureOverlay(isPresented: $showDevCapture)
        }
        #if os(macOS)
        .sheet(item: $selectedSearchNode) { node in
            NodeDetailSheet(node: node)
        }
        #endif
        .onAppear {
            syncNavigationContext()
        }
        .onChange(of: selectedSection) { _, _ in
            syncNavigationContext()
        }
        .onChange(of: selectedDomain?.id) { _, _ in
            syncNavigationContext()
        }
        .onChange(of: isShowingSettings) { _, _ in
            syncNavigationContext()
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: .showGlobalSearch)) { _ in
            toggleGlobalSearch()
        }
        #endif
        .task {
            normalizeDomainOrderIfNeeded()
        }
    }

    // MARK: - macOS

    #if os(macOS)
    var macOSLayout: some View {
        ZStack {
            NavigationSplitView {
                sidebar
                    .navigationSplitViewColumnWidth(
                        min: SymphoTheme.sidebarWidth,
                        ideal: SymphoTheme.sidebarWidth,
                        max: 280
                    )
            } detail: {
                detailContainer
            }
            .navigationSplitViewStyle(.balanced)

            if showGlobalSearch {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { showGlobalSearch = false }

                GlobalSearchView(
                    actions: globalSearchActions,
                    onDismiss: { showGlobalSearch = false }
                )
                .offset(x: SymphoTheme.sidebarWidth / 2)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.snappy(duration: 0.18), value: showGlobalSearch)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    SidebarSearchRow(action: toggleGlobalSearch)
                        .keyboardShortcut("f", modifiers: [.command])

                    navRow(.dashboard)
                    navRow(.inbox)

                    domainsTreeSection

                    MinimalDivider()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)

                    navRow(.projects)
                    navRow(.readingList)
                    navRow(.planner)
                    navRow(.library)
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 14)
            }
            .scrollIndicators(.never)

            sidebarFooter
        }
        .padding(.top, 10)
        .frame(minWidth: SymphoTheme.sidebarWidth)
        .background(.thinMaterial)
    }

    private func navRow(_ section: NavSection) -> some View {
        SidebarRow(
            section: section,
            isSelected: isSectionSelected(section)
        ) {
            selectSection(section)
        }
        .keyboardShortcut(section.shortcut, modifiers: [.command])
    }

    // MARK: - Domains tree

    private var domainsTreeSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            SidebarSectionHeader(
                title: "Domains",
                isSelected: selectedSection == .domains && selectedDomain == nil && !isShowingSettings,
                onSelect: openDomainsRoot,
                onAdd: openDomainsRoot
            )
            .keyboardShortcut("3", modifiers: [.command])

            ForEach(domains) { domain in
                domainTreeItem(domain)
            }
        }
    }

    @ViewBuilder
    private func domainTreeItem(_ domain: Domain) -> some View {
        let isExpanded = expandedDomainIDs.contains(domain.id)

        SidebarTreeRow(
            title: domain.title,
            icon: DomainIcon.validated(domain.iconName),
            indent: 0,
            isSelected: isDomainSelected(domain),
            hasDisclosure: domainHasChildren(domain),
            isExpanded: isExpanded,
            titleWeight: .medium,
            onToggle: { toggleDomain(domain) },
            onSelect: { openDomain(domain) }
        )

        if isExpanded {
            ForEach(activeTracks(in: domain)) { track in
                trackTreeItem(track)
            }
            ForEach(standaloneModules(in: domain)) { module in
                moduleTreeRow(module, indent: 1)
            }
            ForEach(activeProjects(in: domain)) { project in
                projectTreeRow(project, indent: 1)
            }
        }
    }

    @ViewBuilder
    private func trackTreeItem(_ track: Track) -> some View {
        let modules = track.activeModules
        let isExpanded = expandedTrackIDs.contains(track.id)

        SidebarTreeRow(
            title: track.title,
            icon: "point.topleft.down.curvedto.point.bottomright.up",
            indent: 1,
            isSelected: isTrackSelected(track),
            trailing: nil,
            hasDisclosure: !modules.isEmpty,
            isExpanded: isExpanded,
            onToggle: { toggleTrack(track) },
            onSelect: { openTrack(track) }
        )

        if isExpanded {
            ForEach(modules) { module in
                moduleTreeRow(module, indent: 2)
            }
        }
    }

    private func moduleTreeRow(_ module: Module, indent: Int) -> some View {
        SidebarTreeRow(
            title: module.title,
            icon: "square.stack.3d.up",
            indent: indent,
            isSelected: isModuleSelected(module),
            onSelect: { openModule(module) }
        )
    }

    private func projectTreeRow(_ project: Project, indent: Int) -> some View {
        SidebarTreeRow(
            title: project.title,
            icon: "folder",
            indent: indent,
            isSelected: isProjectSelected(project),
            trailing: nil,
            onSelect: { openProject(project) }
        )
    }

    // MARK: - Tree data helpers

    private func activeTracks(in domain: Domain) -> [Track] {
        domain.tracks
            .filter { !$0.isDeletedLocally }
            .sorted { lhs, rhs in
                lhs.sortIndex != rhs.sortIndex ? lhs.sortIndex < rhs.sortIndex : lhs.createdAt < rhs.createdAt
            }
    }

    private func standaloneModules(in domain: Domain) -> [Module] {
        domain.modules
            .filter { !$0.isDeletedLocally && $0.track == nil }
            .sorted { lhs, rhs in
                lhs.sortIndex != rhs.sortIndex ? lhs.sortIndex < rhs.sortIndex : lhs.createdAt < rhs.createdAt
            }
    }

    private func activeProjects(in domain: Domain) -> [Project] {
        domain.projects
            .filter { !$0.isDeletedLocally }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func domainHasChildren(_ domain: Domain) -> Bool {
        !activeTracks(in: domain).isEmpty
            || !standaloneModules(in: domain).isEmpty
            || !activeProjects(in: domain).isEmpty
    }

    // MARK: - Tree selection state

    private func isSectionSelected(_ section: NavSection) -> Bool {
        !isShowingSettings && selectedSection == section
    }

    private func isDomainSelected(_ domain: Domain) -> Bool {
        !isShowingSettings
            && selectedSection == .domains
            && selectedDomain?.id == domain.id
            && selectedTrack == nil
            && selectedModule == nil
            && selectedProject == nil
    }

    private func isTrackSelected(_ track: Track) -> Bool {
        !isShowingSettings
            && selectedTrack?.id == track.id
            && selectedModule == nil
            && selectedProject == nil
    }

    private func isModuleSelected(_ module: Module) -> Bool {
        !isShowingSettings && selectedModule?.id == module.id
    }

    private func isProjectSelected(_ project: Project) -> Bool {
        !isShowingSettings && selectedProject?.id == project.id
    }

    // MARK: - Tree expansion

    private func toggleDomain(_ domain: Domain) {
        withAnimation(.snappy(duration: 0.18)) {
            if expandedDomainIDs.contains(domain.id) {
                expandedDomainIDs.remove(domain.id)
            } else {
                expandedDomainIDs.insert(domain.id)
            }
        }
    }

    private func toggleTrack(_ track: Track) {
        withAnimation(.snappy(duration: 0.18)) {
            if expandedTrackIDs.contains(track.id) {
                expandedTrackIDs.remove(track.id)
            } else {
                expandedTrackIDs.insert(track.id)
            }
        }
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            MinimalDivider()

            if devCaptureEnabled {
                Button {
                    syncNavigationContext()
                    showDevCapture = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "hammer.fill")
                        Text("Dev Capture")
                        Spacer()
                        Text("⌘⇧K")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(SymphoTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SymphoSecondaryButtonStyle())
                .keyboardShortcut("k", modifiers: [.command, .shift])
                .help("Developer capture for bugs and ideas")
            }

            Button {
                showQuickCapture.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Capture")
                    Spacer()
                    Text("⌘K")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SymphoPrimaryButtonStyle())
            .keyboardShortcut("k", modifiers: [.command])
            .help("Quick capture")

            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    isShowingSettings = true
                    selectedDomain = nil
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                    Text("Settings")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SymphoSecondaryButtonStyle())
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
    }

    private var detailContainer: some View {
        detailView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appContentBackground()
            .frame(minWidth: 760, minHeight: 560)
            .background(SymphoTheme.primaryCanvas)
    }

    #endif

    // MARK: - iOS

    #if os(iOS)
    var iOSLayout: some View {
        TabView(selection: $selectedSection) {
            NavigationStack {
                DashboardView(
                    onOpenDomain: openDomain,
                    onOpenTrack: openTrack,
                    onOpenResource: openLibraryResource,
                    onOpenNode: openNode,
                    onOpenProject: openProject
                )
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { showQuickCapture.toggle() }) {
                                Image(systemName: "plus")
                            }
                        }
                    }
            }
            .tabItem { Label(NavSection.dashboard.title, systemImage: NavSection.dashboard.iconName) }
            .tag(NavSection.dashboard)

            NavigationStack { InboxView() }
                .tabItem { Label(NavSection.inbox.title, systemImage: NavSection.inbox.iconName) }
                .tag(NavSection.inbox)

            NavigationStack {
                DomainsView(
                    selectedDomain: $selectedDomain,
                    selectedTrack: $selectedTrack,
                    selectedModule: $selectedModule,
                    selectedProject: $selectedProject,
                    pendingNodeID: $domainsPendingNodeID
                )
            }
            .tabItem { Label(NavSection.domains.title, systemImage: NavSection.domains.iconName) }
            .tag(NavSection.domains)

            NavigationStack { ProjectsView() }
                .tabItem { Label(NavSection.projects.title, systemImage: NavSection.projects.iconName) }
                .tag(NavSection.projects)

            NavigationStack { ReadingListView() }
                .tabItem { Label(NavSection.readingList.title, systemImage: NavSection.readingList.iconName) }
                .tag(NavSection.readingList)

            NavigationStack { PlannerView() }
                .tabItem { Label(NavSection.planner.title, systemImage: NavSection.planner.iconName) }
                .tag(NavSection.planner)

            NavigationStack { LibraryView() }
                .tabItem { Label(NavSection.library.title, systemImage: NavSection.library.iconName) }
                .tag(NavSection.library)
        }
        .tint(SymphoTheme.colorActive)
    }
    #endif

    // MARK: - Router

    @ViewBuilder
    var detailView: some View {
        if isShowingSettings {
            SettingsView()
        } else {
            switch selectedSection {
            case .dashboard:
                DashboardView(
                    onOpenDomain: openDomain,
                    onOpenTrack: openTrack,
                    onOpenResource: openLibraryResource,
                    onOpenNode: openNode,
                    onOpenProject: openProject
                )
            case .inbox:
                InboxView()
            case .domains:
                DomainsView(
                    selectedDomain: $selectedDomain,
                    selectedTrack: $selectedTrack,
                    selectedModule: $selectedModule,
                    selectedProject: $selectedProject,
                    pendingNodeID: $domainsPendingNodeID,
                    onReturnToOrigin: returnToOrigin,
                    onCollapseSidebar: collapseSidebarFully,
                    onCollapseDomainInSidebar: collapseSidebarAfterDomainDismiss,
                    onCollapseTrackInSidebar: { collapseSidebarAfterTrackDismiss($0) }
                )
            case .projects:
                ProjectsView(
                    openProjectID: $projectsOpenProjectID,
                    onReturnToOrigin: returnToOrigin
                )
            case .readingList:
                ReadingListView()
            case .planner:
                PlannerView()
            case .library:
                LibraryView(
                    initialSearchText: librarySearchText,
                    openResourceID: $libraryOpenResourceID,
                    openTagID: $libraryOpenTagID,
                    onReturnToOrigin: returnToOrigin
                )
            }
        }
    }

    private func selectSection(_ section: NavSection) {
        withAnimation(.snappy(duration: 0.18)) {
            navigationContext.returnDestination = nil
            selectedSection = section
            selectedDomain = nil
            selectedTrack = nil
            selectedModule = nil
            selectedProject = nil
            isShowingSettings = false
            collapseSidebarFully()
        }
    }

    private func setReturnFromCurrentSection(entryKind: SymphoNavigationReturn.EntryKind) {
        guard !isShowingSettings else { return }
        guard selectedSection != .domains else { return }

        navigationContext.returnDestination = SymphoNavigationReturn(
            section: selectedSection,
            label: returnLabel(for: selectedSection),
            entryKind: entryKind
        )
    }

    private func returnLabel(for section: NavSection) -> String {
        switch section {
        case .dashboard: return "Home"
        default: return section.title
        }
    }

    private func returnToOrigin(_ destination: SymphoNavigationReturn) {
        withAnimation(.snappy(duration: 0.18)) {
            navigationContext.returnDestination = nil
            selectedSection = destination.section
            selectedDomain = nil
            selectedTrack = nil
            selectedModule = nil
            selectedProject = nil
            domainsPendingNodeID = nil
            projectsOpenProjectID = nil
            libraryOpenResourceID = nil
            libraryOpenTagID = nil
            isShowingSettings = false
            collapseSidebarFully()
        }
    }

    #if os(macOS)
    private func collapseSidebarFully() {
        expandedDomainIDs.removeAll()
        expandedTrackIDs.removeAll()
    }

    private func collapseSidebarAfterTrackDismiss(_ track: Track?) {
        if let track {
            expandedTrackIDs.remove(track.id)
        }
    }

    private func collapseSidebarAfterDomainDismiss(_ domain: Domain?) {
        if let domain {
            expandedDomainIDs.remove(domain.id)
            expandedTrackIDs.removeAll()
        }
    }
    #else
    private func collapseSidebarFully() {}

    private func collapseSidebarAfterTrackDismiss(_ track: Track?) {}

    private func collapseSidebarAfterDomainDismiss(_ domain: Domain?) {}
    #endif

    #if os(macOS)
    private func openSearchNode(_ node: Node) {
        node.markHomeOpened()
        try? modelContext.save()
        selectedSearchNode = node
    }

    private func toggleGlobalSearch() {
        showGlobalSearch.toggle()
    }

    private var globalSearchActions: GlobalSearchActions {
        GlobalSearchActions(
            openNode: openNode,
            openTag: openLibraryTag,
            openDomain: openDomain,
            openTrack: openTrack,
            openModule: openModule,
            openProject: openProject,
            openResource: openLibraryResource
        )
    }

    private func openLibraryResource(_ resource: Resource) {
        resource.markHomeOpened()
        try? modelContext.save()

        setReturnFromCurrentSection(entryKind: .libraryResource(resource.id))

        withAnimation(.snappy(duration: 0.18)) {
            librarySearchText = ""
            libraryOpenResourceID = resource.id
            libraryOpenTagID = nil
            selectedSection = .library
            selectedDomain = nil
            selectedTrack = nil
            selectedModule = nil
            selectedProject = nil
            isShowingSettings = false
        }
    }

    private func openLibraryTag(_ tag: LibraryTag) {
        setReturnFromCurrentSection(entryKind: .libraryTag(tag.id))

        withAnimation(.snappy(duration: 0.18)) {
            librarySearchText = ""
            libraryOpenTagID = tag.id
            libraryOpenResourceID = nil
            selectedSection = .library
            selectedDomain = nil
            selectedTrack = nil
            selectedModule = nil
            selectedProject = nil
            isShowingSettings = false
        }
    }

    private func openLibrarySearch(_ searchText: String) {
        withAnimation(.snappy(duration: 0.18)) {
            librarySearchText = searchText
            selectedSection = .library
            selectedDomain = nil
            selectedTrack = nil
            selectedModule = nil
            selectedProject = nil
            isShowingSettings = false
        }
    }
    #endif

    private func openDomainsRoot() {
        withAnimation(.snappy(duration: 0.18)) {
            selectedSection = .domains
            selectedDomain = nil
            selectedTrack = nil
            selectedModule = nil
            selectedProject = nil
            isShowingSettings = false
        }
    }

    private func openDomain(_ domain: Domain) {
        setReturnFromCurrentSection(entryKind: .domain(domain.id))

        withAnimation(.snappy(duration: 0.18)) {
            selectedSection = .domains
            selectedDomain = domain
            selectedTrack = nil
            selectedModule = nil
            selectedProject = nil
            isShowingSettings = false
            #if os(macOS)
            expandedDomainIDs.insert(domain.id)
            #endif
        }
    }

    private func openTrack(_ track: Track) {
        setReturnFromCurrentSection(entryKind: .track(track.id))

        withAnimation(.snappy(duration: 0.18)) {
            selectedSection = .domains
            selectedDomain = track.domain
            selectedTrack = track
            selectedModule = nil
            selectedProject = nil
            isShowingSettings = false
            #if os(macOS)
            expandTreeFor(domain: track.domain, track: track)
            #endif
        }
    }

    private func openModule(_ module: Module) {
        setReturnFromCurrentSection(entryKind: .module(module.id))

        withAnimation(.snappy(duration: 0.18)) {
            selectedSection = .domains
            selectedDomain = module.resolvedDomain
            selectedTrack = module.track
            selectedModule = module
            selectedProject = nil
            isShowingSettings = false
            #if os(macOS)
            expandTreeFor(domain: module.resolvedDomain, track: module.track)
            #endif
        }
    }

    private func openNode(_ node: Node) {
        node.markHomeOpened()
        try? modelContext.save()

        if node.module != nil || node.project != nil {
            openNodeInWorkspace(node)
        } else {
            #if os(macOS)
            openSearchNode(node)
            #endif
        }
    }

    private func openNodeInWorkspace(_ node: Node) {
        setReturnFromCurrentSection(entryKind: .node(node.id))

        withAnimation(.snappy(duration: 0.18)) {
            selectedSection = .domains
            selectedProject = node.project

            if let module = node.module {
                selectedDomain = module.resolvedDomain
                selectedTrack = module.track
                selectedModule = module
                #if os(macOS)
                expandTreeFor(domain: module.resolvedDomain, track: module.track)
                #endif
            } else if let project = node.project {
                let domain = project.domain ?? project.track?.domain
                selectedDomain = domain
                selectedTrack = project.track
                selectedModule = nil
                #if os(macOS)
                expandTreeFor(domain: domain, track: project.track)
                #endif
            }

            isShowingSettings = false
            domainsPendingNodeID = node.id
        }
    }

    private func openProject(_ project: Project) {
        let domain = project.domain ?? project.track?.domain
        if domain == nil {
            setReturnFromCurrentSection(entryKind: .projectsList(project.id))
        } else {
            setReturnFromCurrentSection(entryKind: .project(project.id))
        }

        if let domain {
            withAnimation(.snappy(duration: 0.18)) {
                selectedSection = .domains
                selectedDomain = domain
                selectedTrack = project.track
                selectedModule = nil
                selectedProject = project
                isShowingSettings = false
                #if os(macOS)
                expandTreeFor(domain: domain, track: project.track)
                #endif
            }
        } else {
            withAnimation(.snappy(duration: 0.18)) {
                selectedSection = .projects
                selectedDomain = nil
                selectedTrack = nil
                selectedModule = nil
                selectedProject = nil
                projectsOpenProjectID = project.id
                isShowingSettings = false
            }
        }
    }

    #if os(macOS)
    private func expandTreeFor(domain: Domain?, track: Track?) {
        if let domain {
            expandedDomainIDs.insert(domain.id)
        }
        if let track {
            expandedTrackIDs.insert(track.id)
        }
    }
    #endif

    private func syncNavigationContext() {
        if isShowingSettings {
            navigationContext.updateShell(
                section: selectedSection,
                domain: selectedDomain,
                isSettings: true
            )
            return
        }

        switch selectedSection {
        case .domains:
            navigationContext.updateDomainWorkspace(
                domain: selectedDomain,
                track: selectedTrack,
                module: selectedModule,
                node: nil,
                project: selectedProject
            )
        case .projects:
            navigationContext.updateProjectsWorkspace(project: selectedProject)
        default:
            navigationContext.updateShell(
                section: selectedSection,
                domain: selectedDomain,
                isSettings: false
            )
        }
    }

    private func normalizeDomainOrderIfNeeded() {
        guard domains.indices.contains(where: { domains[$0].sortIndex != $0 }) else { return }

        for (index, domain) in domains.enumerated() {
            domain.sortIndex = index
            domain.isSynced = false
            domain.updatedAt = Date()
        }

        try? modelContext.save()
    }
}

#if os(macOS)
private struct SidebarSearchRow: View {
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .frame(width: 20)

                Text("Search")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SymphoTheme.secondaryText)

                Spacer(minLength: 8)

                Text("⌘F")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .contentShape(RoundedRectangle(cornerRadius: SymphoTheme.controlRadius, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: SymphoTheme.controlRadius, style: .continuous)
                    .fill(isHovering ? SymphoTheme.elevatedCanvas.opacity(0.42) : .clear)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Search all of Sympho")
    }
}

private struct SidebarRow: View {
    let section: NavSection
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? SymphoTheme.primaryText : SymphoTheme.secondaryText)
                    .frame(width: 20)

                Text(section.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? SymphoTheme.primaryText : SymphoTheme.secondaryText)

                Spacer(minLength: 8)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .contentShape(RoundedRectangle(cornerRadius: SymphoTheme.controlRadius, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: SymphoTheme.controlRadius, style: .continuous)
                    .fill(rowBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: SymphoTheme.controlRadius, style: .continuous)
                    .stroke(isSelected ? .white.opacity(0.28) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var rowBackground: Color {
        if isSelected {
            return SymphoTheme.elevatedCanvas.opacity(0.82)
        }

        if isHovering {
            return SymphoTheme.elevatedCanvas.opacity(0.42)
        }

        return .clear
    }

}

private struct SidebarSectionHeader: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onAdd: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onSelect) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(isSelected ? SymphoTheme.secondaryText : SymphoTheme.tertiaryText)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(SymphoTheme.tertiaryText)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0.5)
            .help("All Domains")
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .onHover { isHovering = $0 }
    }
}

private struct SidebarTreeRow: View {
    let title: String
    let icon: String
    let indent: Int
    let isSelected: Bool
    var trailing: String? = nil
    var hasDisclosure: Bool = false
    var isExpanded: Bool = false
    var titleWeight: Font.Weight = .regular
    var onToggle: () -> Void = {}
    let onSelect: () -> Void

    @State private var isHovering = false

    private var isRoot: Bool { indent == 0 }
    private var indentWidth: CGFloat { CGFloat(indent) * 15 }

    var body: some View {
        HStack(spacing: 5) {
            disclosure

            Button(action: onSelect) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: isRoot ? 14 : 12, weight: .medium))
                        .foregroundStyle(isSelected ? SymphoTheme.primaryText : SymphoTheme.secondaryText)
                        .frame(width: 18)

                    Text(title)
                        .font(.system(size: isRoot ? 13 : 12, weight: isSelected ? .semibold : titleWeight))
                        .foregroundStyle(isSelected ? SymphoTheme.primaryText : SymphoTheme.secondaryText)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if let trailing {
                        Text(trailing)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(SymphoTheme.tertiaryText)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, isRoot ? 6 : 5)
        .padding(.trailing, 10)
        .padding(.leading, 4 + indentWidth)
        .background {
            RoundedRectangle(cornerRadius: SymphoTheme.controlRadius, style: .continuous)
                .fill(rowBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: SymphoTheme.controlRadius, style: .continuous)
                .stroke(isSelected ? .white.opacity(0.22) : .clear, lineWidth: 1)
        }
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var disclosure: some View {
        if hasDisclosure {
            Button(action: onToggle) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(SymphoTheme.tertiaryText)
                    .frame(width: 14, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(width: 14, height: 18)
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return SymphoTheme.elevatedCanvas.opacity(0.82)
        }
        if isHovering {
            return SymphoTheme.elevatedCanvas.opacity(0.42)
        }
        return .clear
    }
}
#endif
