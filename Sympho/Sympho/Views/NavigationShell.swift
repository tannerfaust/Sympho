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
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Home"
        case .inbox: return "Inbox"
        case .domains: return "Domains"
        case .projects: return "Projects"
        case .library: return "Library"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard: return "Active focus and queue"
        case .inbox: return "Unsorted captures"
        case .domains: return "Fields of study"
        case .projects: return "Output workspaces"
        case .library: return "Reference material"
        }
    }

    var iconName: String {
        switch self {
        case .dashboard: return "sparkle.magnifyingglass"
        case .inbox: return "tray"
        case .domains: return "books.vertical"
        case .projects: return "folder"
        case .library: return "books.vertical"
        }
    }

    var shortcut: KeyEquivalent {
        switch self {
        case .dashboard: return "1"
        case .inbox: return "2"
        case .domains: return "3"
        case .projects: return "4"
        case .library: return "5"
        }
    }
}

struct NavigationShell: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSection: NavSection = .dashboard
    @State private var selectedDomain: Domain?
    @State private var isDomainsExpanded = false
    @State private var showQuickCapture = false

    @Query(
        filter: #Predicate<Domain> { !$0.isArchived && !$0.isDeletedLocally },
        sort: [SortDescriptor(\Domain.sortIndex), SortDescriptor(\Domain.title)]
    )
    private var domains: [Domain]

    var syncManager = SyncManager.shared

    var body: some View {
        #if os(macOS)
        macOSLayout
        #else
        iOSLayout
        #endif
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
        .sheet(isPresented: $showQuickCapture) {
            QuickCaptureOverlay(isPresented: $showQuickCapture)
        }
        .task {
            normalizeDomainOrderIfNeeded()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader

            VStack(alignment: .leading, spacing: 8) {
                VStack(spacing: 3) {
                    ForEach(NavSection.allCases) { section in
                        if section == .domains {
                            domainsSidebarGroup
                        } else {
                            SidebarRow(
                                section: section,
                                isSelected: selectedSection == section
                            ) {
                                withAnimation(.snappy(duration: 0.18)) {
                                    selectedSection = section
                                    selectedDomain = nil
                                }
                            }
                            .keyboardShortcut(section.shortcut, modifiers: [.command])
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            Spacer(minLength: 18)

            sidebarFooter
        }
        .frame(minWidth: SymphoTheme.sidebarWidth)
        .background(.thinMaterial)
    }

    private var domainsSidebarGroup: some View {
        VStack(spacing: 2) {
            DomainsSidebarGroupRow(
                isSelected: selectedSection == .domains && selectedDomain == nil,
                isExpanded: isDomainsExpanded,
                onSelect: {
                    withAnimation(.snappy(duration: 0.18)) {
                        selectedSection = .domains
                        selectedDomain = nil
                        isDomainsExpanded = true
                    }
                },
                onToggle: {
                    withAnimation(.snappy(duration: 0.18)) {
                        isDomainsExpanded.toggle()
                    }
                }
            )
            .keyboardShortcut("3", modifiers: [.command])

            if isDomainsExpanded {
                ForEach(domains) { domain in
                    DomainSidebarRow(
                        domain: domain,
                        isSelected: selectedSection == .domains && selectedDomain?.id == domain.id
                    ) {
                        openDomain(domain)
                    }
                }
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
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 11))
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            MinimalDivider()

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
        VStack(spacing: 0) {
            if selectedSection != .domains && selectedSection != .inbox && selectedSection != .projects && selectedSection != .library {
                DetailTopBar(section: selectedSection) {
                    showQuickCapture.toggle()
                }
            }

            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .appContentBackground()
        }
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

            NavigationStack { DomainsView(selectedDomain: $selectedDomain) }
                .tabItem { Label(NavSection.domains.title, systemImage: NavSection.domains.iconName) }
                .tag(NavSection.domains)

            NavigationStack { ProjectsView() }
                .tabItem { Label(NavSection.projects.title, systemImage: NavSection.projects.iconName) }
                .tag(NavSection.projects)

            NavigationStack { LibraryView() }
                .tabItem { Label(NavSection.library.title, systemImage: NavSection.library.iconName) }
                .tag(NavSection.library)
        }
        .tint(SymphoTheme.colorActive)
        .sheet(isPresented: $showQuickCapture) {
            QuickCaptureOverlay(isPresented: $showQuickCapture)
        }
        .task {
            normalizeDomainOrderIfNeeded()
        }
    }
    #endif

    // MARK: - Router

    @ViewBuilder
    var detailView: some View {
        switch selectedSection {
        case .dashboard:
            DashboardView(onOpenDomain: openDomain)
        case .inbox:
            InboxView()
        case .domains:
            DomainsView(selectedDomain: $selectedDomain)
        case .projects:
            ProjectsView()
        case .library:
            LibraryView()
        }
    }

    private func openDomain(_ domain: Domain) {
        withAnimation(.snappy(duration: 0.18)) {
            selectedSection = .domains
            selectedDomain = domain
            #if os(macOS)
            isDomainsExpanded = true
            #endif
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
private struct DetailTopBar: View {
    let section: NavSection
    let onCapture: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(section.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)

                Text(section.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(SymphoTheme.secondaryText)
            }

            Spacer()

            Button {
                onCapture()
            } label: {
                Label("Capture", systemImage: "plus")
            }
            .buttonStyle(SymphoSecondaryButtonStyle())
            .keyboardShortcut("k", modifiers: [.command])
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .bottom) {
            MinimalDivider()
        }
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

private struct DomainsSidebarGroupRow: View {
    let isSelected: Bool
    let isExpanded: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onToggle) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .frame(width: 16, height: 24)
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Collapse Domains" : "Expand Domains")

            Button(action: onSelect) {
                HStack(spacing: 8) {
                    Image(systemName: NavSection.domains.iconName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isSelected ? SymphoTheme.primaryText : SymphoTheme.secondaryText)
                        .frame(width: 20)

                    Text(NavSection.domains.title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? SymphoTheme.primaryText : SymphoTheme.secondaryText)

                    Spacer(minLength: 8)
                }
                .padding(.vertical, 7)
                .padding(.trailing, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 2)
        .background {
            RoundedRectangle(cornerRadius: SymphoTheme.controlRadius, style: .continuous)
                .fill(isSelected ? SymphoTheme.elevatedCanvas.opacity(0.82) : (isHovering ? SymphoTheme.elevatedCanvas.opacity(0.42) : .clear))
        }
        .onHover { isHovering = $0 }
    }
}

private struct DomainSidebarRow: View {
    let domain: Domain
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: DomainIcon.validated(domain.iconName))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? SymphoTheme.primaryText : SymphoTheme.secondaryText)
                    .frame(width: 18)

                Text(domain.title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? SymphoTheme.primaryText : SymphoTheme.secondaryText)
                    .lineLimit(1)

                Spacer(minLength: 8)
            }
            .padding(.vertical, 6)
            .padding(.leading, 38)
            .padding(.trailing, 10)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: SymphoTheme.controlRadius, style: .continuous)
                    .fill(isSelected ? SymphoTheme.elevatedCanvas.opacity(0.82) : (isHovering ? SymphoTheme.elevatedCanvas.opacity(0.42) : .clear))
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
#endif
