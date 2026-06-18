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
        .sheet(isPresented: $showGlobalSearch) {
            GlobalSearchView(
                onOpenNode: openSearchNode,
                onOpenTag: { openLibrarySearch($0.name) },
                onOpenDomain: openDomain,
                onOpenTrack: openTrack,
                onOpenModule: openModule,
                onOpenProject: openProject,
                onOpenResource: { openLibrarySearch($0.title) }
            )
        }
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
            showGlobalSearch = true
        }
        #endif
        .task {
            normalizeDomainOrderIfNeeded()
        }
    }

    // MARK: - macOS

    #if os(macOS)
    var macOSLayout: some View {
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
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
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
            trailing: domainProgressLabel(domain),
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
            trailing: moduleNodeLabel(module),
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

    private func domainProgressLabel(_ domain: Domain) -> String? {
        let nodes = domain.allNodes
        guard !nodes.isEmpty else { return nil }
        let mastered = nodes.filter { $0.status == .mastered }.count
        return "\(Int((Double(mastered) / Double(nodes.count)) * 100))%"
    }

    private func moduleNodeLabel(_ module: Module) -> String? {
        let nodes = module.activeNodes
        guard !nodes.isEmpty else { return nil }
        let mastered = nodes.filter { $0.status == .mastered }.count
        return "\(mastered)/\(nodes.count)"
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

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Sympho")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)

                Spacer()
            }

            Button {
                showGlobalSearch = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(SymphoTheme.tertiaryText)
                        .font(.system(size: 13, weight: .medium))

                    Text("Search everything")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SymphoTheme.tertiaryText)

                    Spacer()

                    Text("⌘F")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                }
                .padding(.horizontal, 11)
                .frame(height: 34)
                .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 11))
            .help("Search all of Sympho")
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            MinimalDivider()

            if devCaptureEnabled {
                Button {
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
                DashboardView(onOpenDomain: openDomain)
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
                    selectedProject: $selectedProject
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
                DashboardView(onOpenDomain: openDomain)
            case .inbox:
                InboxView()
            case .domains:
                DomainsView(
                    selectedDomain: $selectedDomain,
                    selectedTrack: $selectedTrack,
                    selectedModule: $selectedModule,
                    selectedProject: $selectedProject
                )
            case .projects:
                ProjectsView()
            case .readingList:
                ReadingListView()
            case .planner:
                PlannerView()
            case .library:
                LibraryView(initialSearchText: librarySearchText)
            }
        }
    }

    private func selectSection(_ section: NavSection) {
        withAnimation(.snappy(duration: 0.18)) {
            selectedSection = section
            selectedDomain = nil
            selectedTrack = nil
            selectedModule = nil
            selectedProject = nil
            isShowingSettings = false
        }
    }

    #if os(macOS)
    private func openSearchNode(_ node: Node) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            selectedSearchNode = node
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

    #if os(macOS)
    private func openTrack(_ track: Track) {
        withAnimation(.snappy(duration: 0.18)) {
            selectedSection = .domains
            selectedDomain = track.domain
            selectedTrack = track
            selectedModule = nil
            selectedProject = nil
            isShowingSettings = false
        }
    }

    private func openModule(_ module: Module) {
        withAnimation(.snappy(duration: 0.18)) {
            selectedSection = .domains
            selectedDomain = module.resolvedDomain
            selectedTrack = module.track
            selectedModule = module
            selectedProject = nil
            isShowingSettings = false
        }
    }

    private func openProject(_ project: Project) {
        withAnimation(.snappy(duration: 0.18)) {
            selectedSection = .domains
            selectedDomain = project.domain ?? project.track?.domain
            selectedTrack = project.track
            selectedModule = nil
            selectedProject = project
            isShowingSettings = false
        }
    }
    #endif

    private func syncNavigationContext() {
        navigationContext.updateShell(
            section: selectedSection,
            domain: selectedDomain,
            isSettings: isShowingSettings
        )
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
