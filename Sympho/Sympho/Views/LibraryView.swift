//
//  LibraryView.swift
//  Sympho
//
//  Created by Tanner Fause on 30.05.2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
import MarkdownEngine
import QuickLookThumbnailing
#endif

private enum LibraryFilterScope: String, CaseIterable, Identifiable {
    case domains
    case projects
    case readingList

    var id: String { rawValue }

    var title: String {
        switch self {
        case .domains: return "Domains"
        case .projects: return "Projects"
        case .readingList: return "Reading List"
        }
    }
}

private struct FilterUpdateTrigger: Equatable {
    let searchText: String
    let filterScope: LibraryFilterScope
    let selectedDomainID: UUID?
    let selectedProjectID: UUID?
    let selectedTagID: UUID?
    let selectedTagFilterID: UUID?
    let entriesCount: Int
    let nodesCount: Int
    let projectsCount: Int
}

struct LibraryView: View {
    var initialSearchText: String = ""
    @Binding var openResourceID: UUID?
    @Binding var openTagID: UUID?
    var onReturnToOrigin: (SymphoNavigationReturn) -> Void = { _ in }

    init(
        initialSearchText: String = "",
        openResourceID: Binding<UUID?> = .constant(nil),
        openTagID: Binding<UUID?> = .constant(nil),
        onReturnToOrigin: @escaping (SymphoNavigationReturn) -> Void = { _ in }
    ) {
        self.initialSearchText = initialSearchText
        self._openResourceID = openResourceID
        self._openTagID = openTagID
        self.onReturnToOrigin = onReturnToOrigin
    }

    @Query(filter: #Predicate<Resource> { !$0.isDeletedLocally }, sort: \Resource.updatedAt, order: .reverse)
    private var entries: [Resource]

    @Query(
        filter: #Predicate<Domain> { !$0.isArchived && !$0.isDeletedLocally },
        sort: [SortDescriptor(\Domain.sortIndex), SortDescriptor(\Domain.title)]
    )
    private var domains: [Domain]

    @Query(filter: #Predicate<Project> { !$0.isDeletedLocally }, sort: \Project.title)
    private var projects: [Project]

    @Query(filter: #Predicate<Node> { !$0.isDeletedLocally })
    private var allNodes: [Node]

    @Query(filter: #Predicate<ReadingListItem> { !$0.isDeletedLocally })
    private var readingListItems: [ReadingListItem]

    @Query(sort: \LibraryTag.name)
    private var libraryTags: [LibraryTag]

    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigationContext.self) private var navigationContext

    @State private var selectedEntry: Resource?
    @State private var searchText = ""
    @State private var filterScope: LibraryFilterScope = .domains
    @State private var selectedDomain: Domain?
    @State private var selectedProject: Project?
    @State private var selectedReadingTag: LibraryTag?
    @State private var selectedTagFilter: LibraryTag?
    @State private var showsCreateEntry = false
    @State private var showsCompactTitle = false
    @FocusState private var isSearchFocused: Bool

    @State private var cachedFilteredEntries: [Resource] = []

    var body: some View {
        if let selectedEntry {
            LibraryEntryDetailView(
                entry: selectedEntry,
                backTitle: backTitle(for: selectedEntry),
                onBack: { handleEntryBack(selectedEntry) }
            )
        } else {
            overview
        }
    }

    private func backTitle(for entry: Resource) -> String {
        if navigationContext.returnDestination?.entryKind == .libraryResource(entry.id) {
            return navigationContext.returnDestination?.label ?? "Library"
        }
        return "Library"
    }

    private func handleEntryBack(_ entry: Resource) {
        if let destination = navigationContext.returnDestination,
           destination.entryKind == .libraryResource(entry.id) {
            navigationContext.returnDestination = nil
            selectedEntry = nil
            onReturnToOrigin(destination)
            return
        }
        selectedEntry = nil
    }

    private func createNewBlankNote() {
        let newEntry = Resource(
            title: "Untitled Note",
            bodyText: "",
            resourceType: .note,
            domain: filterScope == .domains ? selectedDomain : nil
        )
        if filterScope == .projects, let selectedProject {
            newEntry.projects.append(selectedProject)
            newEntry.domain = selectedProject.domain
        }
        modelContext.insert(newEntry)
        
        // Immediately save the note as a real markdown file in the workspace
        if let imported = try? LibraryStorage.saveMarkdownNote("", entryID: newEntry.id, entryTitle: newEntry.title) {
            let attachment = LibraryAttachment(imported: imported, resource: newEntry)
            modelContext.insert(attachment)
            newEntry.attachments.append(attachment)
        }
        
        try? modelContext.save()
        selectedEntry = newEntry
    }

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                searchBar
                filterBar
                tagFilterBanner

                if filterScope == .readingList {
                    LibraryReadingListSection(
                        searchText: searchText,
                        selectedDomain: selectedDomain,
                        selectedTag: selectedReadingTag
                    )
                } else if cachedFilteredEntries.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 242), spacing: 12)], spacing: 12) {
                        ForEach(cachedFilteredEntries) { entry in
                            LibraryEntryCard(entry: entry) {
                                entry.markHomeOpened()
                                try? modelContext.save()
                                selectedEntry = entry
                            }
                        }
                    }
                    .padding(.horizontal, SymphoTheme.outerPadding)
                    .padding(.bottom, SymphoTheme.outerPadding)
                }
            }
        }
        .libraryScrollChrome(title: "Library", showsCompactTitle: $showsCompactTitle)
        .sheet(isPresented: $showsCreateEntry) {
            CreateLibraryEntrySheet(
                domains: domains,
                initialDomain: filterScope == .domains ? selectedDomain : nil,
                initialProject: filterScope == .projects ? selectedProject : nil
            )
        }
        .task(id: FilterUpdateTrigger(
            searchText: searchText,
            filterScope: filterScope,
            selectedDomainID: selectedDomain?.id,
            selectedProjectID: selectedProject?.id,
            selectedTagID: selectedReadingTag?.id,
            selectedTagFilterID: selectedTagFilter?.id,
            entriesCount: entries.count,
            nodesCount: allNodes.count,
            projectsCount: projects.count
        )) {
            updateFilteredEntries()
        }
        .onAppear {
            if !initialSearchText.isEmpty {
                searchText = initialSearchText
            }
            consumeResourceDeepLink(openResourceID)
            consumeTagDeepLink(openTagID)
        }
        .onChange(of: initialSearchText) { _, newValue in
            guard !newValue.isEmpty else { return }
            searchText = newValue
        }
        .onChange(of: openResourceID) { _, id in
            consumeResourceDeepLink(id)
        }
        .onChange(of: openTagID) { _, id in
            consumeTagDeepLink(id)
        }
        .onChange(of: entries.map(\.id)) { _, _ in
            if openResourceID != nil {
                consumeResourceDeepLink(openResourceID)
            }
        }
        .onChange(of: libraryTags.map(\.id)) { _, _ in
            if openTagID != nil {
                consumeTagDeepLink(openTagID)
            }
        }
    }

    @ViewBuilder
    private var tagFilterBanner: some View {
        if let tag = selectedTagFilter {
            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SymphoTheme.secondaryText)

                Text("Tagged “\(tag.name)”")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SymphoTheme.primaryText)

                Spacer()

                Button("Clear") {
                    selectedTagFilter = nil
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SymphoTheme.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(SymphoTheme.elevatedCanvas.opacity(0.72))
            }
            .padding(.horizontal, SymphoTheme.outerPadding)
            .padding(.bottom, 12)
        }
    }

    private func consumeResourceDeepLink(_ id: UUID?) {
        guard let id, let resource = entries.first(where: { $0.id == id }) else { return }
        resource.markHomeOpened()
        try? modelContext.save()
        selectedTagFilter = nil
        searchText = ""
        selectedEntry = resource
        openResourceID = nil
    }

    private func consumeTagDeepLink(_ id: UUID?) {
        guard let id, let tag = libraryTags.first(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            filterScope = .domains
            selectedDomain = nil
            selectedProject = nil
            selectedReadingTag = nil
            selectedTagFilter = tag
            searchText = ""
            selectedEntry = nil
        }
        openTagID = nil
    }

    private var libraryHeaderSubtitle: String {
        switch filterScope {
        case .readingList:
            let count = readingListItems.count
            return count == 0 ? "No books" : "\(count) book\(count == 1 ? "" : "s")"
        case .domains, .projects:
            let count = entries.count
            return count == 0 ? "No saved entries" : "\(count) saved entr\(count == 1 ? "y" : "ies")"
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Library")
                    .editorialHeader()

                Text(libraryHeaderSubtitle)
                    .metadataSans()
            }

            Spacer()
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SymphoTheme.tertiaryText)

            TextField("Search library", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(SymphoTheme.tertiaryText)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 38)
        .modifier(LibrarySearchSurface(isFocused: isSearchFocused))
        .padding(.horizontal, SymphoTheme.outerPadding)
        .padding(.bottom, 16)
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 2) {
                ForEach(LibraryFilterScope.allCases) { scope in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            filterScope = scope
                            if scope != .readingList {
                                selectedReadingTag = nil
                            }
                            if scope == .readingList {
                                selectedTagFilter = nil
                            }
                        }
                    } label: {
                        Text(scope.title)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background {
                                if filterScope == scope {
                                    Capsule()
                                        .fill(SymphoTheme.primaryText)
                                }
                            }
                            .foregroundStyle(filterScope == scope ? SymphoTheme.primaryCanvas : SymphoTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .glassEffect(.regular.interactive(), in: .capsule)

            HStack(alignment: .center, spacing: 8) {
                switch filterScope {
                case .domains:
                    domainFilters
                case .projects:
                    projectFilters
                case .readingList:
                    readingListFilters
                }

                if filterScope != .readingList {
                    Menu {
                        Button {
                            showsCreateEntry = true
                        } label: {
                            Label("New Reference", systemImage: "paperclip")
                        }

                        Button {
                            createNewBlankNote()
                        } label: {
                            Label("New Markdown Note", systemImage: "note.text.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("New Library Entry")
                }
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
        .padding(.bottom, 16)
    }

    private var domainFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterPill(
                    title: "All Domains",
                    iconName: "books.vertical",
                    isSelected: selectedDomain == nil
                ) {
                    selectedDomain = nil
                }

                ForEach(domains) { domain in
                    filterPill(
                        title: domain.title,
                        iconName: DomainIcon.validated(domain.iconName),
                        isSelected: selectedDomain?.id == domain.id
                    ) {
                        selectedDomain = domain
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var readingListFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterPill(
                    title: "All Books",
                    iconName: "book.closed",
                    isSelected: selectedDomain == nil && selectedReadingTag == nil
                ) {
                    selectedDomain = nil
                    selectedReadingTag = nil
                }

                ForEach(domains) { domain in
                    filterPill(
                        title: domain.title,
                        iconName: DomainIcon.validated(domain.iconName),
                        isSelected: selectedDomain?.id == domain.id && selectedReadingTag == nil
                    ) {
                        selectedDomain = domain
                        selectedReadingTag = nil
                    }
                }

                if !libraryTags.isEmpty {
                    ForEach(libraryTags) { tag in
                        filterPill(
                            title: tag.name,
                            iconName: "tag",
                            isSelected: selectedReadingTag?.id == tag.id
                        ) {
                            selectedReadingTag = tag
                            selectedDomain = nil
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var projectFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterPill(
                    title: "All Projects",
                    iconName: "folder",
                    isSelected: selectedProject == nil
                ) {
                    selectedProject = nil
                }

                ForEach(projects) { project in
                    filterPill(
                        title: project.title,
                        iconName: "folder",
                        isSelected: selectedProject?.id == project.id
                    ) {
                        selectedProject = project
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterPill(title: String, iconName: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                action()
            }
        } label: {
            Label(title, systemImage: iconName)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(isSelected ? SymphoTheme.primaryText : SymphoTheme.elevatedCanvas.opacity(0.42))
                }
                .foregroundStyle(isSelected ? SymphoTheme.primaryCanvas : SymphoTheme.secondaryText)
        }
        .buttonStyle(.plain)
    }

    private func updateFilteredEntries() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let selectedDomainID = selectedDomain?.id
        let selectedProjectID = selectedProject?.id
        let selectedTagFilterID = selectedTagFilter?.id
        
        // Build lookup maps to avoid traversing nested SwiftData relationships in the filter loop
        let projectDomainMap = Dictionary(uniqueKeysWithValues: projects.compactMap { project -> (UUID, UUID)? in
            if let domainID = project.domain?.id {
                return (project.id, domainID)
            }
            return nil
        })
        
        let nodeDomainMap = Dictionary(uniqueKeysWithValues: allNodes.compactMap { node -> (UUID, UUID)? in
            if let domainID = node.module?.track?.domain?.id ?? node.module?.domain?.id {
                return (node.id, domainID)
            }
            return nil
        })
        
        let nodeProjectMap = Dictionary(uniqueKeysWithValues: allNodes.compactMap { node -> (UUID, UUID)? in
            if let projectID = node.project?.id {
                return (node.id, projectID)
            }
            return nil
        })
        
        cachedFilteredEntries = entries.filter {
            let matchesSearch = query.isEmpty ||
                $0.title.lowercased().contains(query) ||
                $0.bodyText.lowercased().contains(query) ||
                $0.urlString.lowercased().contains(query) ||
                $0.attachments.contains { $0.displayName.lowercased().contains(query) } ||
                $0.tags.contains { $0.name.lowercased().contains(query) }

            guard matchesSearch else { return false }

            if let selectedTagFilterID {
                guard $0.tags.contains(where: { $0.id == selectedTagFilterID }) else { return false }
            }

            switch filterScope {
            case .domains:
                guard let selectedDomainID else { return true }
                if $0.domain?.id == selectedDomainID { return true }
                if $0.projects.contains(where: { projectDomainMap[$0.id] == selectedDomainID }) { return true }
                if $0.nodes.contains(where: { nodeDomainMap[$0.id] == selectedDomainID }) { return true }
                return false
            case .projects:
                guard let selectedProjectID else { return true }
                if $0.projects.contains(where: { $0.id == selectedProjectID }) { return true }
                if $0.nodes.contains(where: { nodeProjectMap[$0.id] == selectedProjectID }) { return true }
                return false
            case .readingList:
                return false
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 13) {
            Spacer()

            Image(systemName: "books.vertical")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(SymphoTheme.secondaryText)
                .frame(width: 64, height: 64)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))

            Text(searchText.isEmpty ? "Library empty" : "No matching entries")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SymphoTheme.primaryText)

            Text(searchText.isEmpty ? "Save notes and files together as focused reference entries." : "Try a different search.")
                .metadataSans()

            if searchText.isEmpty {
                Button("New Entry") {
                    showsCreateEntry = true
                }
                .buttonStyle(SymphoSecondaryButtonStyle())
                .padding(.top, 3)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 390)
    }
}

private struct LibraryEntryCard: View {
    @Environment(\.modelContext) private var modelContext

    let entry: Resource
    let onOpen: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 9) {
                preview

                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .lineLimit(1)

                    Text(summaryText)
                        .font(.system(size: 11))
                        .foregroundStyle(SymphoTheme.secondaryText)
                        .lineLimit(2)
                        .frame(height: 28, alignment: .topLeading)
                }

                HStack(spacing: 8) {
                    if let domain = entry.domain {
                        Label(domain.title, systemImage: DomainIcon.validated(domain.iconName))
                            .lineLimit(1)
                    }

                    Spacer()

                    if attachmentCount > 1 {
                        Label("\(attachmentCount)", systemImage: "paperclip")
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(SymphoTheme.tertiaryText)

                if !entry.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(entry.tags.prefix(3)) { tag in
                            Text(tag.name)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(SymphoTheme.tertiaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(SymphoTheme.elevatedCanvas.opacity(0.65), in: .capsule)
                        }
                    }
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .frame(height: 228)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(SymphoTheme.elevatedCanvas.opacity(isHovering ? 0.86 : 0.62))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(isHovering ? SymphoTheme.primaryText.opacity(0.16) : SymphoTheme.dividerColor, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(entry.isPinned ? "Unpin from Home" : "Pin to Home", systemImage: entry.isPinned ? "pin.slash" : "pin") {
                entry.isPinned.toggle()
                entry.updatedAt = Date()
                entry.isSynced = false
                try? modelContext.save()
            }
            Button("Edit", systemImage: "pencil", action: onOpen)
            Button("Delete", role: .destructive) {
                entry.isDeletedLocally = true
                entry.updatedAt = Date()
                entry.isSynced = false
                try? modelContext.save()
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let thumbnailURL = entry.youtubeThumbnailURL {
            LibraryRemoteThumbnail(url: thumbnailURL, fallbackIcon: "play.rectangle")
                .overlay(alignment: .center) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.black.opacity(0.62), in: .circle)
                }
                .overlay(alignment: .bottomLeading) {
                    previewLabel("YOUTUBE", iconName: "play.rectangle")
                }
                .libraryCardPreview()
        } else if let attachment = representativeAttachment {
            LibraryAttachmentThumbnail(attachment: attachment)
                .overlay(alignment: .bottomLeading) {
                    previewLabel(attachment.typeLabel, iconName: attachment.iconName)
                }
                .libraryCardPreview()
        } else {
            VStack(alignment: .leading, spacing: 5) {
                if !entry.bodyText.isEmpty {
                    Text(entry.bodyText)
                        .font(SymphoNoteTypography.previewFont)
                        .foregroundStyle(SymphoTheme.secondaryText)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "note.text")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(SymphoTheme.tertiaryText)
                        Text("Empty Note")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(SymphoTheme.tertiaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .padding(12)
            .background(SymphoTheme.secondarySurface.opacity(0.55))
            .libraryCardPreview()
        }
    }

    private func previewLabel(_ title: String, iconName: String) -> some View {
        Label(title, systemImage: iconName)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.black.opacity(0.56), in: .capsule)
            .padding(7)
    }

    private var attachmentCount: Int {
        entry.attachments.count + (entry.fileRelativePath == nil ? 0 : 1)
    }

    private var representativeAttachment: LibraryDisplayAttachment? {
        if let attachment = entry.attachments.sorted(by: { $0.previewPriority < $1.previewPriority }).first {
            return LibraryDisplayAttachment(
                id: attachment.id,
                name: attachment.displayName,
                contentType: attachment.contentType,
                byteSize: attachment.byteSize,
                url: LibraryStorage.resolvedURL(for: attachment)
            )
        }

        guard let legacyURL = LibraryStorage.legacyResolvedURL(for: entry) else { return nil }
        return LibraryDisplayAttachment(
            id: entry.id,
            name: legacyURL.lastPathComponent,
            contentType: UTType(filenameExtension: legacyURL.pathExtension)?.identifier ?? UTType.data.identifier,
            byteSize: nil,
            url: legacyURL
        )
    }

    private var iconName: String {
        if attachmentCount > 1 { return "doc.on.doc" }
        if attachmentCount == 1 { return "paperclip" }
        return entry.resourceType.iconName
    }

    private var summaryText: String {
        if !entry.bodyText.isEmpty { return entry.bodyText }
        if attachmentCount > 0 { return "\(attachmentCount) attached file\(attachmentCount == 1 ? "" : "s")" }
        if let url = URL(string: entry.urlString), !url.isFileURL { return entry.urlString }
        return "Saved reference entry"
    }
}

private struct LibraryEntryDetailView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext

    let entry: Resource
    var backTitle: String = "Library"
    let onBack: () -> Void

    @Query(
        filter: #Predicate<Domain> { !$0.isArchived && !$0.isDeletedLocally },
        sort: [SortDescriptor(\Domain.sortIndex), SortDescriptor(\Domain.title)]
    )
    private var domains: [Domain]

    @State private var title: String
    @State private var bodyText: String
    @State private var selectedDomain: Domain?
    @State private var selectedTags: [LibraryTag]
    @State private var linkedBook: ReadingListItem?

    @Query(sort: \LibraryTag.name) private var allTags: [LibraryTag]

    @Query(
        filter: #Predicate<ReadingListItem> { !$0.isDeletedLocally },
        sort: \ReadingListItem.title
    )
    private var readingBooks: [ReadingListItem]

    @State private var showsCompactTitle = false
    @State private var selectedFilePreview: LibraryPreviewFile?

    init(entry: Resource, backTitle: String = "Library", onBack: @escaping () -> Void) {
        self.entry = entry
        self.backTitle = backTitle
        self.onBack = onBack
        _title = State(initialValue: entry.title)
        _selectedDomain = State(initialValue: entry.domain)
        _selectedTags = State(initialValue: entry.tags)
        _linkedBook = State(initialValue: entry.readingListItem)

        var initialBodyText = entry.bodyText
        if let mdAttachment = entry.attachments.first(where: { $0.isMarkdown }),
           let url = LibraryStorage.resolvedURL(for: mdAttachment),
           let fileContent = try? String(contentsOf: url, encoding: .utf8) {
            initialBodyText = fileContent
        } else if let legacyURL = LibraryStorage.legacyResolvedURL(for: entry),
                  let fileContent = try? String(contentsOf: legacyURL, encoding: .utf8) {
            initialBodyText = fileContent
        }
        _bodyText = State(initialValue: initialBodyText)
    }

    private func saveChanges() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let titleChanged = entry.title != trimmedTitle
        let domainChanged = entry.domain?.id != selectedDomain?.id
        
        if titleChanged || domainChanged {
            entry.title = trimmedTitle
            entry.domain = selectedDomain
            entry.updatedAt = Date()
            entry.isSynced = false
        }
        
        var bodyChanged = false
        if let mdAttachment = entry.attachments.first(where: { $0.isMarkdown }) {
            if let url = LibraryStorage.resolvedURL(for: mdAttachment) {
                let existingContent = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                if existingContent != bodyText {
                    try? LibraryStorage.updateMarkdownNote(bodyText, attachment: mdAttachment)
                    bodyChanged = true
                }
            }
        } else if let legacyURL = LibraryStorage.legacyResolvedURL(for: entry) {
            let existingContent = (try? String(contentsOf: legacyURL, encoding: .utf8)) ?? ""
            if existingContent != bodyText {
                try? bodyText.write(to: legacyURL, atomically: true, encoding: .utf8)
                bodyChanged = true
            }
        } else if entry.resourceType == .note {
            if let imported = try? LibraryStorage.saveMarkdownNote(bodyText, entryID: entry.id, entryTitle: trimmedTitle) {
                let attachment = LibraryAttachment(imported: imported, resource: entry)
                modelContext.insert(attachment)
                entry.attachments.append(attachment)
                bodyChanged = true
            }
        } else {
            if entry.bodyText != bodyText {
                entry.bodyText = bodyText
                bodyChanged = true
            }
        }
        
        if bodyChanged {
            entry.bodyText = bodyText
            entry.updatedAt = Date()
            entry.isSynced = false
        }
        
        let tagNames = selectedTags.map(\.name).sorted()
        let existingTagNames = entry.tags.map(\.name).sorted()
        let tagsChanged = tagNames != existingTagNames
        if tagsChanged {
            var tagCache = allTags
            LibraryTagsHelper.applyTags(names: selectedTags.map(\.name), to: entry, in: modelContext, allTags: &tagCache)
            entry.updatedAt = Date()
            entry.isSynced = false
        }

        let bookChanged = entry.readingListItem?.id != linkedBook?.id
        if bookChanged {
            if let previous = entry.readingListItem {
                previous.linkedResources.removeAll { $0.id == entry.id }
            }
            entry.readingListItem = linkedBook
            if let linkedBook, !linkedBook.linkedResources.contains(where: { $0.id == entry.id }) {
                linkedBook.linkedResources.append(entry)
            }
            entry.updatedAt = Date()
            entry.isSynced = false
        }

        if titleChanged || domainChanged || bodyChanged || tagsChanged || bookChanged {
            try? modelContext.save()
        }
    }

    private var changeSignature: String {
        let tagsKey = selectedTags.map(\.id.uuidString).sorted().joined(separator: ",")
        let bookKey = linkedBook?.id.uuidString ?? "none"
        return "\(title)-\(bodyText)-\(selectedDomain?.id.uuidString ?? "")-\(tagsKey)-\(bookKey)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                detailHeader

                readingListLinkSection

                LibraryTagsField(selectedTags: $selectedTags)
                    .padding(.top, 4)

                noteEditorSection

                if !entry.urlString.isEmpty && entry.fileRelativePath == nil {
                    sourceLink
                }

                youtubePreview
                attachmentsSection
            }
            .padding(.horizontal, SymphoTheme.outerPadding)
            .padding(.top, 16)
            .padding(.bottom, SymphoTheme.outerPadding)
        }
        .libraryScrollChrome(title: title.isEmpty ? "Note Detail" : title, showsCompactTitle: $showsCompactTitle)
        .sheet(item: $selectedFilePreview) { preview in
            LibraryFilePreviewSheet(file: preview)
        }
        .task(id: changeSignature) {
            do {
                try await Task.sleep(for: .milliseconds(800))
                saveChanges()
            } catch {}
        }
        .onDisappear {
            saveChanges()
        }
    }
    
    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                SymphoGlassBackButton(title: backTitle, action: onBack)

                Button {
                    entry.isPinned.toggle()
                    entry.updatedAt = Date()
                    entry.isSynced = false
                    try? modelContext.save()
                } label: {
                    Image(systemName: entry.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .help(entry.isPinned ? "Unpin from Home" : "Pin to Home")
            }

            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .frame(width: 54, height: 54)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 5) {
                    TextField("Entry title", text: $title)
                        .font(.system(size: 28, weight: .semibold))
                        .textFieldStyle(.plain)
                        .foregroundColor(SymphoTheme.primaryText)

                    HStack(spacing: 12) {
                        if !domains.isEmpty {
                            Menu {
                                Button {
                                    selectedDomain = nil
                                } label: {
                                    Label("No Domain", systemImage: selectedDomain == nil ? "checkmark" : "circle")
                                }

                                Divider()

                                ForEach(domains) { domain in
                                    Button {
                                        selectedDomain = domain
                                    } label: {
                                        Label(domain.title, systemImage: selectedDomain?.id == domain.id ? "checkmark" : DomainIcon.validated(domain.iconName))
                                    }
                                }
                            } label: {
                                Label(selectedDomain?.title ?? "Add Domain", systemImage: selectedDomain.map { DomainIcon.validated($0.iconName) } ?? "plus")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(SymphoTheme.secondaryText)
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                        }
                        
                        Text("·")
                            .foregroundStyle(SymphoTheme.tertiaryText)
                            
                        Text("\(attachments.count) file\(attachments.count == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundStyle(SymphoTheme.secondaryText)
                    }
                }
            }
        }
    }

    private var readingListLinkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reading list")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SymphoTheme.secondaryText)

            if readingBooks.isEmpty {
                Text("No books in your reading list yet.")
                    .font(.system(size: 11))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            } else {
                Picker("Linked book", selection: $linkedBook) {
                    Text("None").tag(ReadingListItem?.none)
                    ForEach(readingBooks) { book in
                        Text(book.title).tag(Optional(book))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
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

    private var noteEditorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SymphoTheme.primaryText)
            
            MarkdownNoteEditor(text: $bodyText, documentId: entry.id.uuidString)
                .frame(minHeight: 420)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                }
                .frame(maxWidth: 760)
        }
    }

    @ViewBuilder
    private var youtubePreview: some View {
        if let thumbnailURL = entry.youtubeThumbnailURL, let destination = normalizedURL {
            Button {
                openURL(destination)
            } label: {
                LibraryRemoteThumbnail(url: thumbnailURL, fallbackIcon: "play.rectangle")
                    .frame(maxWidth: 620)
                    .frame(height: 240)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(.black.opacity(0.62), in: .circle)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var sourceLink: some View {
        Button {
            guard let url = normalizedURL else { return }
            openURL(url)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(SymphoTheme.primaryText)
                
                Text(entry.urlString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(SymphoTheme.secondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(SymphoTheme.primaryText.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 720)
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Files")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SymphoTheme.primaryText)

            if attachments.isEmpty {
                Text("No attached files.")
                    .font(.system(size: 12))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .librarySurface()
            } else {
                VStack(spacing: 8) {
                    ForEach(attachments) { attachment in
                        LibraryAttachmentCard(attachment: attachment) {
                            open(attachment)
                        }
                    }
                }
            }
        }
    }

    private var normalizedURL: URL? {
        let trimmed = entry.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)")
    }

    private var attachments: [LibraryDisplayAttachment] {
        var allAttachments = entry.attachments
        if entry.resourceType == .note {
            if let primaryMd = allAttachments.first(where: { $0.isMarkdown }) {
                allAttachments.removeAll(where: { $0.id == primaryMd.id })
            }
        }
        
        var result = allAttachments.map {
            LibraryDisplayAttachment(
                id: $0.id,
                name: $0.displayName,
                contentType: $0.contentType,
                byteSize: $0.byteSize,
                url: LibraryStorage.resolvedURL(for: $0)
            )
        }

        if let legacyURL = LibraryStorage.legacyResolvedURL(for: entry) {
            let isLegacyMarkdown = legacyURL.pathExtension.lowercased() == "md"
            if !(entry.resourceType == .note && isLegacyMarkdown) {
                result.append(
                    LibraryDisplayAttachment(
                        id: entry.id,
                        name: legacyURL.lastPathComponent,
                        contentType: UTType(filenameExtension: legacyURL.pathExtension)?.identifier ?? UTType.data.identifier,
                        byteSize: nil,
                        url: legacyURL
                    )
                )
            }
        }

        return result
    }

    private func open(_ attachment: LibraryDisplayAttachment) {
        guard let url = attachment.url else { return }

        let preview = LibraryPreviewFile(
            id: attachment.id,
            title: attachment.name,
            contentType: attachment.contentType,
            url: url,
            byteSize: attachment.byteSize
        )

        if preview.isPreviewable {
            selectedFilePreview = preview
        } else {
            LibraryFileActions.openExternally(url)
        }
    }
}

private struct LibraryAttachmentCard: View {
    let attachment: LibraryDisplayAttachment
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                preview

                Label(attachment.name, systemImage: attachment.iconName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(1)

                Spacer()

                Text(attachment.sizeLabel ?? attachment.typeLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(SymphoTheme.tertiaryText)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(SymphoTheme.dividerColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var preview: some View {
        LibraryAttachmentThumbnail(attachment: attachment)
            .frame(width: 58, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct CreateLibraryEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let domains: [Domain]
    let initialProject: Project?

    @State private var title = ""
    @State private var bodyText = ""
    @State private var sourceURL = ""
    @State private var selectedDomain: Domain?
    @State private var selectedTags: [LibraryTag] = []
    @State private var selectedFiles: [URL] = []
    @State private var showsFileImporter = false
    @State private var importErrorMessage: String?
    @State private var draftDocumentId = UUID().uuidString

    @Query(sort: \LibraryTag.name) private var allTags: [LibraryTag]

    init(domains: [Domain], initialDomain: Domain? = nil, initialProject: Project? = nil) {
        self.domains = domains
        self.initialProject = initialProject
        _selectedDomain = State(initialValue: initialDomain ?? initialProject?.domain)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            sheetHeader

            VStack(spacing: 10) {
                LibraryInputRow(title: "Name", iconName: "character.textbox") {
                    TextField("Entry title", text: $title)
                        .textFieldStyle(.plain)
                }

                LibraryInputRow(title: "Source", iconName: "link") {
                    TextField("Optional URL", text: $sourceURL)
                        .textFieldStyle(.plain)
                }

                if !domains.isEmpty {
                    LibraryInputRow(title: "Domain", iconName: "books.vertical") {
                        Picker("Domain", selection: $selectedDomain) {
                            Text("None").tag(Domain?.none)
                            ForEach(domains) { domain in
                                Text(domain.title).tag(Optional(domain))
                            }
                        }
                        .labelsHidden()
                    }
                }

                LibraryTagsField(selectedTags: $selectedTags)
            }

            notesEditor
            filesEditor

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(SymphoSecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save Entry") {
                    save()
                }
                .buttonStyle(SymphoPrimaryButtonStyle())
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 560)
        .background(SymphoTheme.primaryCanvas)
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: LibraryFileClassifier.importableContentTypes,
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            selectedFiles.append(contentsOf: urls.filter { !selectedFiles.contains($0) })
        }
        .alert("Some files could not be saved", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )) {
            Button("Done") {
                dismiss()
            }
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    private var sheetHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(SymphoTheme.primaryText)
                .frame(width: 50, height: 50)
                .glassEffect(.regular, in: .rect(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 5) {
                Text("New Library Entry")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)

                Text("Combine a note, source link, and any number of files into one reference entry.")
                    .font(.system(size: 12))
                    .foregroundStyle(SymphoTheme.secondaryText)
            }
        }
    }

    private var notesEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.system(size: 12, weight: .medium))

            MarkdownNoteEditor(text: $bodyText, documentId: draftDocumentId)
                .frame(minHeight: 160)
                .librarySurface()
        }
    }

    private var filesEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Files")
                    .font(.system(size: 12, weight: .medium))

                Spacer()

                Button {
                    showsFileImporter = true
                } label: {
                    Label("Add Files", systemImage: "paperclip")
                }
                .buttonStyle(SymphoSecondaryButtonStyle())
            }

            if selectedFiles.isEmpty {
                Text("No files attached.")
                    .font(.system(size: 12))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .librarySurface()
            } else {
                VStack(spacing: 0) {
                    ForEach(selectedFiles, id: \.self) { file in
                        HStack {
                            Image(systemName: "doc")
                                .foregroundStyle(SymphoTheme.secondaryText)

                            Text(file.lastPathComponent)
                                .font(.system(size: 12))
                                .lineLimit(1)

                            Spacer()

                            Button {
                                selectedFiles.removeAll { $0 == file }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(SymphoTheme.tertiaryText)
                        }
                        .padding(.horizontal, 11)
                        .frame(height: 36)
                    }
                }
                .librarySurface()
            }
        }
    }

    private func save() {
        let entry = Resource(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            bodyText: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
            urlString: sourceURL.trimmingCharacters(in: .whitespacesAndNewlines),
            resourceType: sourceURL.isEmpty ? .note : .url,
            domain: selectedDomain
        )
        if let initialProject {
            entry.projects.append(initialProject)
        }
        modelContext.insert(entry)

        var tagCache = allTags
        LibraryTagsHelper.applyTags(names: selectedTags.map(\.name), to: entry, in: modelContext, allTags: &tagCache)

        var failedFiles: [String] = []
        for file in selectedFiles {
            do {
                let imported = try LibraryStorage.importFile(from: file, entryID: entry.id, entryTitle: entry.title)
                let attachment = LibraryAttachment(imported: imported, resource: entry)
                modelContext.insert(attachment)
                entry.attachments.append(attachment)
            } catch {
                failedFiles.append("\(file.lastPathComponent): \(error.localizedDescription)")
            }
        }

        try? modelContext.save()
        if failedFiles.isEmpty {
            dismiss()
        } else {
            importErrorMessage = "The entry was saved, but Sympho could not copy: \(failedFiles.joined(separator: ", "))."
        }
    }
}

private struct LibraryInputRow<Content: View>: View {
    let title: String
    let iconName: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SymphoTheme.secondaryText)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SymphoTheme.primaryText)
                .frame(width: 62, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 42)
        .librarySurface()
    }
}



private struct LibraryDisplayAttachment: Identifiable {
    let id: UUID
    let name: String
    let contentType: String
    let byteSize: Int64?
    let url: URL?

    var isImage: Bool {
        UTType(contentType)?.conforms(to: .image) == true
    }

    var isVideo: Bool {
        UTType(contentType)?.conforms(to: .movie) == true
    }

    var iconName: String {
        if isImage { return "photo" }
        if isVideo { return "film" }
        if UTType(contentType)?.conforms(to: .pdf) == true { return "doc.richtext" }
        if isMarkdown { return "note.text" }
        return "doc"
    }

    var typeLabel: String {
        if isImage { return "IMAGE" }
        if isVideo { return "VIDEO" }
        if UTType(contentType)?.conforms(to: .pdf) == true { return "PDF" }
        if isMarkdown { return "NOTE" }
        return "FILE"
    }

    var sizeLabel: String? {
        LibraryFileClassifier.formattedByteSize(byteSize)
    }

    var isMarkdown: Bool {
        contentType == "net.daringfireball.markdown" || name.lowercased().hasSuffix(".md")
    }
}

private struct LibraryImagePreview: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}

private struct LibraryImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let preview: LibraryImagePreview

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(preview.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
            .padding(14)

            LibraryLocalImage(url: preview.url)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(18)
        }
        .frame(minWidth: 680, minHeight: 520)
        .background(SymphoTheme.primaryCanvas)
    }
}

private struct LibraryLocalImage: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        #if os(macOS)
        if let image {
            Image(nsImage: image)
                .resizable()
        } else {
            fallback
                .task(id: url) {
                    image = await LibraryFullImageCache.shared.image(for: url)
                }
        }
        #else
        fallback
        #endif
    }

    private var fallback: some View {
        Image(systemName: "photo")
            .resizable()
            .scaledToFit()
            .foregroundStyle(SymphoTheme.secondaryText)
    }
}

private struct LibraryRemoteThumbnail: View {
    let url: URL
    let fallbackIcon: String

    #if os(macOS)
    @State private var image: NSImage?
    #endif

    var body: some View {
        Group {
            #if os(macOS)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                remotePlaceholder
            }
            #else
            remotePlaceholder
            #endif
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: 126)
        .clipped()
        #if os(macOS)
        .task(id: url) {
            image = await LibraryRemoteThumbnailCache.shared.image(for: url)
        }
        #endif
    }

    private var remotePlaceholder: some View {
        ZStack {
            SymphoTheme.secondarySurface.opacity(0.55)
            Image(systemName: fallbackIcon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(SymphoTheme.secondaryText)
        }
        .frame(height: 126)
        .frame(maxWidth: .infinity)
    }
}

private struct LibraryAttachmentThumbnail: View {
    let attachment: LibraryDisplayAttachment

    #if os(macOS)
    @State private var thumbnail: NSImage?
    #endif

    var body: some View {
        ZStack {
            SymphoTheme.secondarySurface.opacity(0.55)

            #if os(macOS)
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 126)
                    .clipped()
            } else {
                fallback
            }
            #else
            fallback
            #endif
        }
        .frame(height: 126)
        .frame(maxWidth: .infinity)
        .clipped()
        #if os(macOS)
        .task(id: attachment.id) {
            guard let url = attachment.url else { return }
            thumbnail = await LibraryThumbnailCache.shared.thumbnail(
                for: url,
                contentType: attachment.contentType
            )
        }
        #endif
    }

    private var fallback: some View {
        Image(systemName: attachment.iconName)
            .font(.system(size: 30, weight: .light))
            .foregroundStyle(SymphoTheme.secondaryText)
            .frame(height: 126)
            .frame(maxWidth: .infinity)
    }

}

#if os(macOS)
@MainActor
private final class LibraryRemoteThumbnailCache {
    static let shared = LibraryRemoteThumbnailCache()

    private let cache = NSCache<NSURL, NSImage>()
    private var inFlight: [URL: Task<NSImage?, Never>] = [:]
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.timeoutIntervalForRequest = 12
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    private init() {
        cache.countLimit = 48
        cache.totalCostLimit = 24 * 1024 * 1024
    }

    func image(for url: URL) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        if let task = inFlight[url] {
            return await task.value
        }

        let task = Task<NSImage?, Never> {
            guard !Task.isCancelled else { return nil }

            do {
                let (data, response) = try await session.data(from: url)
                guard !Task.isCancelled,
                      let http = response as? HTTPURLResponse,
                      (200 ... 299).contains(http.statusCode),
                      let image = NSImage(data: data) else {
                    return nil
                }

                return image
            } catch {
                return nil
            }
        }

        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil

        if let image {
            cache.setObject(image, forKey: url as NSURL, cost: imageCost(image))
        }

        return image
    }

    private func imageCost(_ image: NSImage) -> Int {
        Int(image.size.width * image.size.height * 4)
    }
}

@MainActor
private final class LibraryFullImageCache {
    static let shared = LibraryFullImageCache()

    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        cache.countLimit = 12
        cache.totalCostLimit = 96 * 1024 * 1024
    }

    func image(for url: URL) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        let data = LibraryStorage.data(at: url)
        guard let data, let image = NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: url as NSURL, cost: Int(image.size.width * image.size.height * 4))
        return image
    }
}

@MainActor
private final class LibraryThumbnailCache {
    static let shared = LibraryThumbnailCache()

    private let cache = NSCache<NSURL, NSImage>()
    private var requests: [URL: Task<NSImage?, Never>] = [:]

    private init() {
        cache.countLimit = 96
        cache.totalCostLimit = 48 * 1024 * 1024
    }

    func thumbnail(for url: URL, contentType: String) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        if let request = requests[url] {
            return await request.value
        }

        let request = Task { await generateThumbnail(for: url, contentType: contentType) }
        requests[url] = request
        let image = await request.value
        requests[url] = nil

        if let image {
            cache.setObject(image, forKey: url as NSURL, cost: imageCost(image))
        }

        return image
    }

    private func generateThumbnail(for url: URL, contentType: String) async -> NSImage? {
        guard FileManager.default.isReadableFile(atPath: url.path) else { return nil }

        let type = UTType(contentType) ?? UTType(filenameExtension: url.pathExtension)
        if type?.conforms(to: .plainText) == true || url.pathExtension.lowercased() == "md" {
            return nil
        }

        if type?.conforms(to: .image) == true {
            return loadImageThumbnail(at: url)
        }

        guard shouldUseQuickLook(for: type) else { return nil }

        await QLThumbnailGate.shared.acquire()
        let thumbnail = await quickLookThumbnail(at: url)
        await QLThumbnailGate.shared.release()
        return thumbnail
    }

    private func loadImageThumbnail(at url: URL) -> NSImage? {
        LibraryStorage.withWorkspaceAccess {
            guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
                  let image = NSImage(data: data) else {
                return nil
            }

            return downsampled(image, maxPixelSize: 460)
        }
    }

    private func shouldUseQuickLook(for type: UTType?) -> Bool {
        guard let type else { return false }
        if type.conforms(to: .image) { return false }
        if type.conforms(to: .plainText) { return false }
        return type.conforms(to: .pdf)
            || type.conforms(to: .movie)
            || type.conforms(to: .audiovisualContent)
    }

    private func quickLookThumbnail(at url: URL) async -> NSImage? {
        await withCheckedContinuation { continuation in
            LibraryStorage.withWorkspaceAccess {
                let request = QLThumbnailGenerator.Request(
                    fileAt: url,
                    size: CGSize(width: 460, height: 264),
                    scale: NSScreen.main?.backingScaleFactor ?? 2,
                    representationTypes: .thumbnail
                )

                QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
                    continuation.resume(returning: thumbnail?.nsImage)
                }
            }
        }
    }

    private func downsampled(_ image: NSImage, maxPixelSize: CGFloat) -> NSImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxPixelSize, longest > 0 else { return image }

        let scale = maxPixelSize / longest
        let target = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let scaled = NSImage(size: target)
        scaled.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: target),
            from: .zero,
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        scaled.unlockFocus()
        return scaled
    }

    private func imageCost(_ image: NSImage) -> Int {
        Int(image.size.width * image.size.height * 4)
    }
}

private actor QLThumbnailGate {
    static let shared = QLThumbnailGate()

    private let limit = 2
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if active < limit {
            active += 1
            return
        }

        await withCheckedContinuation { waiters.append($0) }
        active += 1
    }

    func release() {
        active = max(0, active - 1)
        if waiters.isEmpty { return }
        waiters.removeFirst().resume()
    }
}
#endif

private struct LibraryScrollChrome: ViewModifier {
    let title: String
    @Binding var showsCompactTitle: Bool

    func body(content: Content) -> some View {
        content
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 38
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

private struct LibrarySearchSurface: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(SymphoTheme.elevatedCanvas.opacity(isFocused ? 0.18 : 0.58))

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.001))
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                        .opacity(isFocused ? 1 : 0)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isFocused ? SymphoTheme.primaryText.opacity(0.18) : SymphoTheme.dividerColor,
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(isFocused ? 0.06 : 0), radius: 8, y: 2)
            .animation(.easeInOut(duration: 0.16), value: isFocused)
        }
}

private extension View {
    func libraryScrollChrome(title: String, showsCompactTitle: Binding<Bool>) -> some View {
        modifier(LibraryScrollChrome(title: title, showsCompactTitle: showsCompactTitle))
    }

    func librarySurface() -> some View {
        background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SymphoTheme.elevatedCanvas.opacity(0.58))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        }
    }

    func libraryCardPreview() -> some View {
        frame(maxWidth: .infinity)
            .frame(height: 126)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension LibraryAttachment {
    var isMarkdown: Bool {
        contentType == "net.daringfireball.markdown" || displayName.lowercased().hasSuffix(".md")
    }

    var previewPriority: Int {
        guard let type = UTType(contentType) else { return 3 }
        if type.conforms(to: .image) { return 0 }
        if type.conforms(to: .movie) { return 1 }
        return 2
    }
}
