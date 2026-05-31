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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let domain = selectedDomain {
                DomainDetailView(domain: domain) {
                    selectedDomain = nil
                }
            } else {
                domainsListView
            }
        }
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

// MARK: - Domain Detail View (Nested)

struct DomainDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let domain: Domain
    var onBack: () -> Void
    
    @State private var selectedTab = 0 // 0: Curriculum, 1: Local Library, 2: Roadmap Blueprint
    
    // Editor triggers
    @State private var showCreateTrack = false
    @State private var showCreateModule = false
    
    // Form fields
    @State private var newTrackTitle = ""
    @State private var newTrackDesc = ""
    
    @State private var newModuleTitle = ""
    @State private var newModuleDesc = ""
    @State private var targetTrackForModule: Track? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Domain Detail Header
            VStack(alignment: .leading, spacing: 14) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                        Text("Back to Domains")
                    }
                    .font(.caption)
                    .foregroundColor(SymphoTheme.secondaryText)
                }
                .buttonStyle(.plain)
                
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: DomainIcon.validated(domain.iconName))
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .frame(width: 52, height: 52)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(SymphoTheme.elevatedCanvas.opacity(0.62))
                        }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(domain.title)
                            .editorialHeader()

                        if !domain.desc.isEmpty {
                            Text(domain.desc)
                                .metadataSans()
                        }

                        HStack(spacing: 12) {
                            WorkspaceFact(iconName: "square.stack.3d.up", text: "\(activeTracks.count) tracks")
                            WorkspaceFact(iconName: "checklist", text: "\(domain.allNodes.count) nodes")
                            WorkspaceFact(iconName: "doc.text", text: "\(domain.allResources.count) materials")
                        }
                        .padding(.top, 2)
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, SymphoTheme.outerPadding)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            HStack(spacing: 18) {
                DomainWorkspaceTab(title: "Curriculum", iconName: "list.bullet.rectangle", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                DomainWorkspaceTab(title: "Library", iconName: "books.vertical", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                DomainWorkspaceTab(title: "Roadmap", iconName: "map", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
                Spacer()
            }
            .padding(.horizontal, SymphoTheme.outerPadding)
            .padding(.bottom, 10)
            
            MinimalDivider()
            
            // Tab contents
            switch selectedTab {
            case 0:
                curriculumSyllabusTab
            case 1:
                localLibraryTab
            default:
                BlueprintView(domain: domain)
            }
        }
        .sheet(isPresented: $showCreateTrack) {
            createTrackSheet
        }
        .sheet(isPresented: $showCreateModule) {
            createModuleSheet
        }
    }
    
    // MARK: - Curriculum Syllabus Tab
    
    private var curriculumSyllabusTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SymphoTheme.sectionSpacing) {
                // Section action controls
                HStack(spacing: SymphoTheme.gridSpacing) {
                    Button(action: { showCreateTrack = true }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Track")
                        }
                        .foregroundColor(SymphoTheme.primaryText)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(SymphoTheme.secondarySurface)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        targetTrackForModule = nil
                        showCreateModule = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Standalone Module")
                        }
                        .foregroundColor(SymphoTheme.primaryText)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(SymphoTheme.secondarySurface)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
                
                let activeTracks = domain.tracks.filter { !$0.isDeletedLocally }
                let activeStandaloneModules = domain.modules.filter { !$0.isDeletedLocally && $0.track == nil }
                
                if activeTracks.isEmpty && activeStandaloneModules.isEmpty {
                    VStack(spacing: 8) {
                        Text("No learning tracks defined in this domain.")
                            .font(.system(.body, design: .default))
                            .foregroundColor(SymphoTheme.secondaryText)
                        Text("Create a track (like 'Fundamentals' or 'Applied Mechanics') to organize courses.")
                            .captionSans()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
                } else {
                    // Render Tracks
                    if !activeTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Tracks")
                                .editorialSubtitle()
                            
                            ForEach(activeTracks) { track in
                                TrackAccordion(track: track) {
                                    targetTrackForModule = track
                                    showCreateModule = true
                                }
                            }
                        }
                    }
                    
                    // Render Standalone Modules directly in the Domain
                    if !activeStandaloneModules.isEmpty {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Standalone Modules")
                                .editorialSubtitle()
                            
                            ForEach(activeStandaloneModules) { module in
                                ModuleAccordion(module: module)
                            }
                        }
                    }
                }
            }
            .padding(SymphoTheme.outerPadding)
        }
    }

    private var activeTracks: [Track] {
        domain.tracks.filter { !$0.isDeletedLocally }
    }
    
    // MARK: - Local Library Tab (Trickle Up)
    
    private var localLibraryTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SymphoTheme.sectionSpacing) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Domain Assets Library")
                        .editorialSubtitle()
                    Text("Showing all items attached anywhere within this domain (trickled-up from tracks, modules, and nodes).")
                        .captionSans()
                }
                .padding(.top, 4)
                
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
                                
                                if let url = URL(string: res.urlString) {
                                    Link(res.urlString, destination: url)
                                        .font(.caption)
                                        .foregroundColor(SymphoTheme.colorActive)
                                        .lineLimit(1)
                                } else {
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
            .padding(SymphoTheme.outerPadding)
        }
    }
    
    // MARK: - Track / Module Sheets
    
    private var createTrackSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Track details")) {
                    TextField("Track Title (e.g. Advanced Deep Learning)", text: $newTrackTitle)
                    TextField("Track Description", text: $newTrackDesc)
                }
            }
            .navigationTitle("Add Track")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreateTrack = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let track = Track(
                            title: newTrackTitle,
                            desc: newTrackDesc,
                            domain: domain
                        )
                        modelContext.insert(track)
                        domain.tracks.append(track)
                        domain.isSynced = false
                        try? modelContext.save()
                        newTrackTitle = ""
                        newTrackDesc = ""
                        showCreateTrack = false
                    }
                    .disabled(newTrackTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 260)
        #endif
    }
    
    private var createModuleSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Module details")) {
                    TextField("Module Title (e.g. Transformer Architectures)", text: $newModuleTitle)
                    TextField("Module Description", text: $newModuleDesc)
                }
            }
            .navigationTitle(targetTrackForModule != nil ? "Add Module to \(targetTrackForModule!.title)" : "Add Standalone Module")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreateModule = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let module = Module(
                            title: newModuleTitle,
                            desc: newModuleDesc,
                            track: targetTrackForModule,
                            domain: targetTrackForModule == nil ? domain : nil
                        )
                        modelContext.insert(module)
                        
                        if let track = targetTrackForModule {
                            track.modules.append(module)
                            track.isSynced = false
                        } else {
                            domain.modules.append(module)
                            domain.isSynced = false
                        }
                        
                        try? modelContext.save()
                        newModuleTitle = ""
                        newModuleDesc = ""
                        showCreateModule = false
                    }
                    .disabled(newModuleTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 260)
        #endif
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

private struct DomainWorkspaceTab: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                Text(title)
            }
            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            .foregroundStyle(isSelected ? SymphoTheme.primaryText : SymphoTheme.secondaryText)
            .padding(.vertical, 7)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isSelected ? SymphoTheme.primaryText : .clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Track Accordion Component

struct TrackAccordion: View {
    let track: Track
    var onAddModule: () -> Void
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(action: { isExpanded.toggle() }) {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(SymphoTheme.secondaryText)
                        Text(track.title)
                            .editorialSubtitle()
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: onAddModule) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(SymphoTheme.colorActive)
                }
                .buttonStyle(.plain)
            }
            
            if isExpanded {
                if !track.desc.isEmpty {
                    Text(track.desc)
                        .font(.caption)
                        .foregroundColor(SymphoTheme.secondaryText)
                        .padding(.leading, 24)
                }
                
                let activeModules = track.modules.filter { !$0.isDeletedLocally }
                if activeModules.isEmpty {
                    Text("No syllabus modules in this track.")
                        .font(.caption)
                        .italic()
                        .foregroundColor(SymphoTheme.secondaryText)
                        .padding(.leading, 24)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 8) {
                        ForEach(activeModules) { module in
                            ModuleAccordion(module: module)
                        }
                    }
                    .padding(.leading, 12)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(SymphoTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: SymphoTheme.cornerRadius)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        )
    }
}

// MARK: - Module Accordion Component

struct ModuleAccordion: View {
    @Environment(\.modelContext) private var modelContext
    let module: Module
    @State private var isExpanded = false
    @State private var showCreateNode = false
    @State private var newNodeTitle = ""
    @State private var newNodeDesc = ""
    
    @State private var selectedNodeForDetails: Node? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: { isExpanded.toggle() }) {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(SymphoTheme.secondaryText)
                            .font(.caption)
                        Text(module.title)
                            .font(.system(size: 14, weight: .semibold, design: .default))
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: { showCreateNode = true }) {
                    HStack(spacing: 2) {
                        Image(systemName: "plus")
                        Text("Add Node")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(SymphoTheme.colorActive)
                }
                .buttonStyle(.plain)
            }
            
            if isExpanded {
                let activeNodes = module.nodes.filter { !$0.isDeletedLocally }
                if activeNodes.isEmpty {
                    Text("No learning nodes defined.")
                        .font(.caption)
                        .italic()
                        .foregroundColor(SymphoTheme.secondaryText)
                        .padding(.leading, 20)
                } else {
                    VStack(spacing: 4) {
                        ForEach(activeNodes) { node in
                            Button(action: {
                                selectedNodeForDetails = node
                            }) {
                                HStack {
                                    // Status icon
                                    Image(systemName: nodeStatusIcon(node.status))
                                        .foregroundColor(nodeStatusColor(node.status))
                                        .font(.caption)
                                    
                                    Text(node.title)
                                        .font(.system(size: 13))
                                        .foregroundColor(SymphoTheme.primaryText)
                                    
                                    if node.priority == .critical {
                                        Text("CRITICAL")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(SymphoTheme.colorCritical)
                                            .cornerRadius(2)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(SymphoTheme.secondaryText)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(SymphoTheme.elevatedCanvas.opacity(0.50))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 12)
                }
            }
        }
        .padding(10)
        .background(SymphoTheme.secondarySurface.opacity(0.4))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        )
        .sheet(isPresented: $showCreateNode) {
            createNodeSheet
        }
        .sheet(item: $selectedNodeForDetails) { node in
            NodeDetailSheet(node: node)
        }
    }
    
    // MARK: - Helpers
    
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
    
    private var createNodeSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Node particulars")) {
                    TextField("Node Title (e.g. Backpropagation Math)", text: $newNodeTitle)
                    TextField("Description / What to master", text: $newNodeDesc)
                }
            }
            .navigationTitle("New Node")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreateNode = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let node = Node(
                            title: newNodeTitle,
                            desc: newNodeDesc,
                            module: module
                        )
                        modelContext.insert(node)
                        module.nodes.append(node)
                        module.isSynced = false
                        try? modelContext.save()
                        newNodeTitle = ""
                        newNodeDesc = ""
                        showCreateNode = false
                    }
                    .disabled(newNodeTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 260)
        #endif
    }
}
