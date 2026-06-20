//
//  ReadingListView.swift
//  Sympho
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Entry

struct ReadingListView: View {
    var body: some View {
        ReadingListWorkspace(presentation: .main)
    }
}

// MARK: - Workspace

struct ReadingListWorkspace: View {
    enum Presentation {
        case main
        case libraryEmbedded
    }

    @Environment(\.modelContext) private var modelContext

    let presentation: Presentation
    var externalSearchText: String
    var selectedDomain: Domain?
    var selectedTag: LibraryTag?

    init(
        presentation: Presentation,
        externalSearchText: String = "",
        selectedDomain: Domain? = nil,
        selectedTag: LibraryTag? = nil
    ) {
        self.presentation = presentation
        self.externalSearchText = externalSearchText
        self.selectedDomain = selectedDomain
        self.selectedTag = selectedTag
    }

    @Query(
        filter: #Predicate<ReadingListItem> { !$0.isDeletedLocally },
        sort: [SortDescriptor(\ReadingListItem.sortIndex), SortDescriptor(\ReadingListItem.updatedAt, order: .reverse)]
    )
    private var allItems: [ReadingListItem]

    @Query(sort: [SortDescriptor(\ReadingListGroup.sortIndex), SortDescriptor(\ReadingListGroup.title)])
    private var allGroups: [ReadingListGroup]

    @Query(
        filter: #Predicate<Domain> { !$0.isArchived && !$0.isDeletedLocally },
        sort: [SortDescriptor(\Domain.sortIndex), SortDescriptor(\Domain.title)]
    )
    private var domains: [Domain]

    @State private var shelf: ReadingShelf = .all
    @State private var viewStyle: ReadingViewStyle = .list
    @State private var groupFilterID: UUID?
    @State private var priorityOnlyHigh = false
    @State private var localSearchText = ""

    @State private var showsCreateSheet = false
    @State private var showsNewGroupAlert = false
    @State private var newGroupTitle = ""
    @State private var selectedItem: ReadingListItem?
    @State private var draggedItemID: UUID?

    private var effectiveSearch: String {
        presentation == .main ? localSearchText : externalSearchText
    }

    private var filteredItems: [ReadingListItem] {
        let query = effectiveSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return allItems.filter { item in
            if !query.isEmpty {
                let matches = item.title.lowercased().contains(query)
                    || item.author.lowercased().contains(query)
                    || item.notes.lowercased().contains(query)
                    || item.progressMarker.lowercased().contains(query)
                    || item.tags.contains { $0.name.lowercased().contains(query) }
                guard matches else { return false }
            }

            if let status = shelf.status, item.status != status { return false }
            if priorityOnlyHigh, item.priority != .high { return false }
            if let selectedDomain, item.domain?.id != selectedDomain.id { return false }
            if let selectedTag, !item.tags.contains(where: { $0.id == selectedTag.id }) { return false }

            if let groupFilterID {
                if groupFilterID == ReadingListFilterTokens.ungroupedID {
                    return item.group == nil
                }
                return item.group?.id == groupFilterID
            }

            return true
        }
    }

    private var sortedFiltered: [ReadingListItem] {
        filteredItems.sorted(by: readingSort)
    }

    private var groupedSections: [ReadingGroupSection] {
        let grouped = Dictionary(grouping: sortedFiltered) { item in
            item.group?.id.uuidString ?? ReadingListFilterTokens.ungroupedKey
        }

        var sections: [ReadingGroupSection] = allGroups.compactMap { group in
            guard let items = grouped[group.id.uuidString], !items.isEmpty else { return nil }
            return ReadingGroupSection(id: group.id.uuidString, title: group.title, items: items)
        }

        if let ungrouped = grouped[ReadingListFilterTokens.ungroupedKey], !ungrouped.isEmpty {
            sections.append(ReadingGroupSection(id: ReadingListFilterTokens.ungroupedKey, title: "No group", items: ungrouped))
        }

        return sections
    }

    private var showGroupedSections: Bool {
        presentation == .main
            && shelf == .all
            && groupFilterID == nil
            && !allGroups.isEmpty
            && sortedFiltered.contains(where: { $0.group != nil })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if presentation == .main {
                    mainHeader
                } else {
                    embeddedHeader
                }
                controls
                booksContent
            }
            .padding(.bottom, SymphoTheme.outerPadding)
        }
        .background(SymphoTheme.primaryCanvas)
        .sheet(isPresented: $showsCreateSheet) {
            ReadingListEditorSheet(mode: .create, domains: domains, groups: allGroups)
        }
        .sheet(item: $selectedItem) { item in
            ReadingListEditorSheet(mode: .edit(item), domains: domains, groups: allGroups)
        }
        .alert("New group", isPresented: $showsNewGroupAlert) {
            TextField("Name", text: $newGroupTitle)
            Button("Cancel", role: .cancel) { newGroupTitle = "" }
            Button("Add") { createGroup() }
        }
    }

    // MARK: - Chrome

    private var mainHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Reading")
                    .editorialHeader()
                Text(headerSubtitle)
                    .metadataSans()
            }
            Spacer(minLength: 0)
            SymphoGlassAddButton(help: "Add book") {
                showsCreateSheet = true
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    private var embeddedHeader: some View {
        HStack {
            Spacer()
            SymphoGlassAddButton(help: "Add book", size: 30, iconSize: 14) {
                showsCreateSheet = true
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
        .padding(.bottom, 8)
    }

    private var headerSubtitle: String {
        if allItems.isEmpty { return "Books you want to read, are reading, or have finished." }
        let reading = allItems.filter { $0.status == .reading }.count
        if reading > 0 {
            return "\(allItems.count) books · \(reading) in progress"
        }
        return "\(allItems.count) book\(allItems.count == 1 ? "" : "s")"
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            if presentation == .main {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                    TextField("Search books", text: $localSearchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                    if !localSearchText.isEmpty {
                        Button { localSearchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(SymphoTheme.tertiaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 4)
            }

            statusShelf

            HStack(spacing: 8) {
                filterMenu
                Spacer(minLength: 0)
                viewStyleToggle
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
        .padding(.bottom, 18)
    }

    private var statusShelf: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(ReadingShelf.allCases) { option in
                    Button {
                        withAnimation(.snappy(duration: 0.15)) { shelf = option }
                    } label: {
                        Text(option.label)
                            .font(.system(size: 12, weight: shelf == option ? .semibold : .medium))
                            .foregroundStyle(shelf == option ? SymphoTheme.primaryText : SymphoTheme.secondaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background {
                                if shelf == option {
                                    Capsule()
                                        .fill(SymphoTheme.elevatedCanvas.opacity(0.9))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Section("Group") {
                Button("All groups") { groupFilterID = nil }
                Button("No group") { groupFilterID = ReadingListFilterTokens.ungroupedID }
                ForEach(allGroups) { group in
                    Button(group.title) { groupFilterID = group.id }
                }
                Divider()
                Button("New group…") { showsNewGroupAlert = true }
            }
            Section("Priority") {
                Button(priorityOnlyHigh ? "✓ High only" : "High only") {
                    priorityOnlyHigh.toggle()
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 11, weight: .semibold))
                Text(filterMenuTitle)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(filtersActive ? SymphoTheme.primaryText : SymphoTheme.secondaryText)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var filterMenuTitle: String {
        if let groupFilterID {
            if groupFilterID == ReadingListFilterTokens.ungroupedID { return "No group" }
            if let group = allGroups.first(where: { $0.id == groupFilterID }) { return group.title }
        }
        if priorityOnlyHigh { return "High priority" }
        return "Filter"
    }

    private var filtersActive: Bool {
        groupFilterID != nil || priorityOnlyHigh
    }

    private var viewStyleToggle: some View {
        HStack(spacing: 2) {
            Button {
                withAnimation(.snappy(duration: 0.15)) { viewStyle = .list }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(viewStyle == .list ? SymphoTheme.primaryText : SymphoTheme.tertiaryText)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.snappy(duration: 0.15)) { viewStyle = .gallery }
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(viewStyle == .gallery ? SymphoTheme.primaryText : SymphoTheme.tertiaryText)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Books

    @ViewBuilder
    private var booksContent: some View {
        if sortedFiltered.isEmpty {
            emptyState
        } else if viewStyle == .gallery {
            galleryContent
        } else if showGroupedSections {
            groupedListContent
        } else {
            flatListContent
        }
    }

    private var flatListContent: some View {
        VStack(spacing: 0) {
            ForEach(sortedFiltered) { item in
                bookEntry(item)
                if item.id != sortedFiltered.last?.id {
                    readingListDivider
                }
            }
        }
        .readingListSurface()
        .padding(.horizontal, SymphoTheme.outerPadding)
    }

    private var groupedListContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(groupedSections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                        .tracking(0.4)
                        .padding(.leading, 4)

                    VStack(spacing: 0) {
                        ForEach(section.items) { item in
                            bookEntry(item)
                            if item.id != section.items.last?.id {
                                readingListDivider
                            }
                        }
                    }
                    .readingListSurface()
                }
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
    }

    private var galleryContent: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 148), spacing: 12)],
            spacing: 12
        ) {
            ForEach(sortedFiltered) { item in
                ReadingListBookTile(item: item) {
                    selectedItem = item
                }
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
    }

    private func bookEntry(_ item: ReadingListItem) -> some View {
        ReadingListBookRow(item: item) {
            selectedItem = item
        }
        #if os(macOS)
        .onDrag {
            draggedItemID = item.id
            return NSItemProvider(object: item.id.uuidString as NSString)
        }
        .onDrop(
            of: [.text],
            delegate: ReadingListReorderDropDelegate(
                destinationID: item.id,
                orderedIDs: sortedFiltered.map(\.id),
                draggedID: draggedItemID,
                onReorder: applyOrder
            ) { draggedItemID = nil }
        )
        #endif
    }

    private var readingListDivider: some View {
        Rectangle()
            .fill(SymphoTheme.dividerColor.opacity(0.65))
            .frame(height: 1)
            .padding(.leading, 58)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(SymphoTheme.tertiaryText)
            Text(emptyMessage)
                .font(.system(size: 13))
                .foregroundStyle(SymphoTheme.secondaryText)
                .multilineTextAlignment(.center)
            if presentation == .main && effectiveSearch.isEmpty && !filtersActive && shelf == .all {
                Button("Add a book") { showsCreateSheet = true }
                    .font(.system(size: 12, weight: .semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(SymphoTheme.primaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, presentation == .main ? 64 : 32)
        .padding(.horizontal, SymphoTheme.outerPadding)
    }

    private var emptyMessage: String {
        if !effectiveSearch.isEmpty { return "No books match your search." }
        if filtersActive || shelf != .all { return "Nothing here with these filters." }
        return "Your reading list is empty."
    }

    // MARK: - Actions

    private func createGroup() {
        let title = newGroupTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let group = ReadingListGroup(title: title, sortIndex: allGroups.count)
        modelContext.insert(group)
        try? modelContext.save()
        newGroupTitle = ""
        groupFilterID = group.id
    }

    private func applyOrder(_ ids: [UUID]) {
        let byID = Dictionary(uniqueKeysWithValues: allItems.map { ($0.id, $0) })
        for (index, id) in ids.enumerated() {
            byID[id]?.sortIndex = index
            byID[id]?.updatedAt = Date()
        }
        try? modelContext.save()
    }

    private func readingSort(_ lhs: ReadingListItem, _ rhs: ReadingListItem) -> Bool {
        if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
        return lhs.updatedAt > rhs.updatedAt
    }
}

// MARK: - Editor sheet

struct ReadingListEditorSheet: View {
    enum Mode {
        case create
        case edit(ReadingListItem)

        var isEdit: Bool {
            if case .edit = self { return true }
            return false
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let mode: Mode
    let domains: [Domain]
    let groups: [ReadingListGroup]

    @Query(filter: #Predicate<Module> { !$0.isDeletedLocally }, sort: \Module.title)
    private var allModules: [Module]

    @Query(sort: \LibraryTag.name) private var allTags: [LibraryTag]

    @Query(filter: #Predicate<Resource> { !$0.isDeletedLocally }, sort: \Resource.title)
    private var allResources: [Resource]

    @State private var title = ""
    @State private var author = ""
    @State private var notes = ""
    @State private var urlString = ""
    @State private var status: ReadingStatus = .queue
    @State private var priority: ReadingPriority = .normal
    @State private var stoppedAtVolume = ""
    @State private var stoppedAtPage = ""
    @State private var selectedDomain: Domain?
    @State private var selectedModule: Module?
    @State private var selectedGroup: ReadingListGroup?
    @State private var selectedTags: [LibraryTag] = []
    @State private var linkedResourceIDs: Set<UUID> = []

    private var editingItem: ReadingListItem? {
        if case .edit(let item) = mode { return item }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(mode.isEdit ? "Book" : "New book")
                .font(.system(size: 22, weight: .semibold))

            ScrollView {
                VStack(spacing: 12) {
                    editorField("Title") {
                        TextField("Title", text: $title).textFieldStyle(.plain)
                    }
                    editorField("Author") {
                        TextField("Author", text: $author).textFieldStyle(.plain)
                    }
                    editorField("Status") {
                        Picker("", selection: $status) {
                            ForEach(ReadingStatus.allCases) { s in
                                Text(s.displayName).tag(s)
                            }
                        }
                        .labelsHidden()
                    }
                    editorField("Priority") {
                        Picker("", selection: $priority) {
                            ForEach(ReadingPriority.allCases) { p in
                                Text(p.displayName).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    editorField("Progress") {
                        HStack(spacing: 10) {
                            TextField("Volume", text: $stoppedAtVolume).textFieldStyle(.plain)
                            TextField("Page", text: $stoppedAtPage).textFieldStyle(.plain)
                        }
                    }
                    if !groups.isEmpty {
                        editorField("Group") {
                            Picker("", selection: $selectedGroup) {
                                Text("None").tag(ReadingListGroup?.none)
                                ForEach(groups) { group in
                                    Text(group.title).tag(Optional(group))
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    editorField("Link") {
                        TextField("URL", text: $urlString).textFieldStyle(.plain)
                    }
                    if !domains.isEmpty {
                        editorField("Domain") {
                            Picker("", selection: $selectedDomain) {
                                Text("None").tag(Domain?.none)
                                ForEach(domains) { domain in
                                    Text(domain.title).tag(Optional(domain))
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    if !moduleOptions.isEmpty {
                        editorField("Module") {
                            Picker("", selection: $selectedModule) {
                                Text("None").tag(Module?.none)
                                ForEach(moduleOptions) { module in
                                    Text(module.title).tag(Optional(module))
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    LibraryTagsField(selectedTags: $selectedTags)

                    editorField("Notes") {
                        TextField("Notes", text: $notes, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(3...8)
                    }

                    linkedResourcesSection
                }
            }
            .frame(maxHeight: 440)

            HStack {
                if mode.isEdit {
                    Button("Delete", role: .destructive) {
                        editingItem?.isDeletedLocally = true
                        try? modelContext.save()
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                Button(mode.isEdit ? "Save" : "Add") { save(); dismiss() }
                    .buttonStyle(SymphoPrimaryButtonStyle())
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        #if os(macOS)
        .frame(width: 480)
        #endif
        .onAppear(perform: loadDraft)
    }

    private var moduleOptions: [Module] {
        guard let selectedDomain else { return allModules }
        let trackModules = selectedDomain.tracks.flatMap { $0.modules.filter { !$0.isDeletedLocally } }
        let standalone = selectedDomain.modules.filter { !$0.isDeletedLocally && $0.track == nil }
        return (standalone + trackModules).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    @ViewBuilder
    private var linkedResourcesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Library links")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SymphoTheme.secondaryText)

            if allResources.isEmpty {
                Text("No library entries yet.")
                    .font(.system(size: 11))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(allResources.prefix(20)) { resource in
                        Button { toggleResourceLink(resource) } label: {
                            HStack {
                                Image(systemName: resource.resourceType.iconName)
                                    .frame(width: 18)
                                Text(resource.title)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                Spacer()
                                if linkedResourceIDs.contains(resource.id) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        if resource.id != allResources.prefix(20).last?.id {
                            Divider()
                        }
                    }
                }
                .readingListSurface()
            }
        }
    }

    private func loadDraft() {
        guard let item = editingItem else { return }
        title = item.title
        author = item.author
        notes = item.notes
        urlString = item.urlString
        status = item.status
        priority = item.priority
        stoppedAtVolume = item.stoppedAtVolume
        stoppedAtPage = item.stoppedAtPage
        selectedDomain = item.domain
        selectedModule = item.module
        selectedGroup = item.group
        selectedTags = item.tags
        linkedResourceIDs = Set(item.linkedResources.map(\.id))
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let item: ReadingListItem
        switch mode {
        case .create:
            item = ReadingListItem(
                title: trimmed,
                author: author.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                urlString: urlString.trimmingCharacters(in: .whitespacesAndNewlines),
                status: status,
                priority: priority,
                stoppedAtVolume: stoppedAtVolume.trimmingCharacters(in: .whitespacesAndNewlines),
                stoppedAtPage: stoppedAtPage.trimmingCharacters(in: .whitespacesAndNewlines),
                sortIndex: (try? allItemsCount()) ?? 0,
                domain: selectedDomain,
                module: selectedModule,
                group: selectedGroup
            )
            modelContext.insert(item)
        case .edit(let existing):
            item = existing
            item.title = trimmed
            item.author = author.trimmingCharacters(in: .whitespacesAndNewlines)
            item.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            item.urlString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            item.status = status
            item.priority = priority
            item.stoppedAtVolume = stoppedAtVolume.trimmingCharacters(in: .whitespacesAndNewlines)
            item.stoppedAtPage = stoppedAtPage.trimmingCharacters(in: .whitespacesAndNewlines)
            item.domain = selectedDomain
            item.module = selectedModule
            item.group = selectedGroup
            item.updatedAt = Date()
        }

        var tagCache = allTags
        LibraryTagsHelper.applyTags(names: selectedTags.map(\.name), to: item, in: modelContext, allTags: &tagCache)
        syncResourceLinks(for: item)
        try? modelContext.save()
    }

    private func allItemsCount() -> Int {
        let descriptor = FetchDescriptor<ReadingListItem>(predicate: #Predicate { !$0.isDeletedLocally })
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    private func toggleResourceLink(_ resource: Resource) {
        if linkedResourceIDs.contains(resource.id) {
            linkedResourceIDs.remove(resource.id)
        } else {
            linkedResourceIDs.insert(resource.id)
        }
    }

    private func syncResourceLinks(for item: ReadingListItem) {
        for resource in allResources {
            let shouldLink = linkedResourceIDs.contains(resource.id)
            let isLinked = resource.readingListItem?.id == item.id
            if shouldLink {
                resource.readingListItem = item
                if !item.linkedResources.contains(where: { $0.id == resource.id }) {
                    item.linkedResources.append(resource)
                }
            } else if isLinked {
                resource.readingListItem = nil
                item.linkedResources.removeAll { $0.id == resource.id }
            }
        }
    }
}

// MARK: - Book views

struct ReadingListBookRow: View {
    @Environment(\.modelContext) private var modelContext

    let item: ReadingListItem
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 14) {
                bookSpine

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(SymphoTheme.primaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if item.priority == .high {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(SymphoTheme.colorCritical)
                        }
                    }

                    if !item.author.isEmpty {
                        Text(item.author)
                            .font(.system(size: 13))
                            .foregroundStyle(SymphoTheme.secondaryText)
                            .lineLimit(1)
                    }

                    if let meta = secondaryMeta {
                        Text(meta)
                            .font(.system(size: 11))
                            .foregroundStyle(SymphoTheme.tertiaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                statusControl
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onTap)
            Button("Delete", role: .destructive, action: softDeleteItem)
            Divider()
            ForEach(ReadingStatus.allCases) { status in
                Button(status.displayName) {
                    item.status = status
                    item.updatedAt = Date()
                    try? modelContext.save()
                }
            }
        }
    }

    private func softDeleteItem() {
        item.isDeletedLocally = true
        item.updatedAt = Date()
        try? modelContext.save()
    }

    private var bookSpine: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(readingStatusColor(item.status))
            .frame(width: 4, height: 44)
    }

    private var secondaryMeta: String? {
        var parts: [String] = []
        if !item.progressMarker.isEmpty { parts.append(item.progressMarker) }
        if let group = item.group?.title { parts.append(group) }
        if !item.linkedResources.isEmpty { parts.append("\(item.linkedResources.count) linked") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var statusControl: some View {
        Menu {
            ForEach(ReadingStatus.allCases) { status in
                Button(status.displayName) {
                    item.status = status
                    item.updatedAt = Date()
                    try? modelContext.save()
                }
            }
        } label: {
            Text(item.status.shortLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(readingStatusColor(item.status))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

struct ReadingListBookTile: View {
    @Environment(\.modelContext) private var modelContext

    let item: ReadingListItem
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(readingStatusColor(item.status).opacity(0.14))
                    .frame(height: 72)
                    .overlay {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(readingStatusColor(item.status))
                    }

                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !item.author.isEmpty {
                    Text(item.author)
                        .font(.system(size: 11))
                        .foregroundStyle(SymphoTheme.secondaryText)
                        .lineLimit(1)
                }

                Text(item.status.shortLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(readingStatusColor(item.status))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .symphoCardContextMenu(edit: onTap, delete: { softDeleteItem() })
    }

    private func softDeleteItem() {
        item.isDeletedLocally = true
        item.updatedAt = Date()
        try? modelContext.save()
    }
}

// MARK: - Types

private enum ReadingShelf: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case all, queue, reading, paused, finished

    var label: String {
        switch self {
        case .all: return "All"
        case .queue: return "Want to read"
        case .reading: return "Reading"
        case .paused: return "Paused"
        case .finished: return "Finished"
        }
    }

    var status: ReadingStatus? {
        switch self {
        case .all: return nil
        case .queue: return .queue
        case .reading: return .reading
        case .paused: return .paused
        case .finished: return .finished
        }
    }
}

private enum ReadingViewStyle {
    case list
    case gallery
}

private enum ReadingListFilterTokens {
    static let ungroupedKey = "ungrouped"
    static let ungroupedID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}

private struct ReadingGroupSection: Identifiable {
    let id: String
    let title: String
    let items: [ReadingListItem]
}

private extension ReadingStatus {
    var shortLabel: String {
        switch self {
        case .queue: return "Queue"
        case .reading: return "Reading"
        case .paused: return "Paused"
        case .finished: return "Done"
        }
    }
}

@ViewBuilder
private func editorField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(SymphoTheme.secondaryText)
        content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}

private extension View {
    func readingListSurface() -> some View {
        background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SymphoTheme.elevatedCanvas.opacity(0.35))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(SymphoTheme.dividerColor.opacity(0.8), lineWidth: 1)
        }
    }
}

func readingStatusColor(_ status: ReadingStatus) -> Color {
    switch status {
    case .queue: return SymphoTheme.secondaryText
    case .reading: return SymphoTheme.colorActive
    case .paused: return SymphoTheme.colorMastered.opacity(0.85)
    case .finished: return SymphoTheme.colorMastered
    }
}

func readingPriorityColor(_ priority: ReadingPriority) -> Color {
    switch priority {
    case .low: return SymphoTheme.tertiaryText
    case .normal: return SymphoTheme.secondaryText
    case .high: return SymphoTheme.colorCritical
    }
}

#if os(macOS)
struct ReadingListReorderDropDelegate: DropDelegate {
    let destinationID: UUID
    let orderedIDs: [UUID]
    let draggedID: UUID?
    let onReorder: ([UUID]) -> Void
    let onEnd: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedID, draggedID != destinationID,
              let source = orderedIDs.firstIndex(of: draggedID),
              let destination = orderedIDs.firstIndex(of: destinationID) else { return }
        var reordered = orderedIDs
        reordered.move(
            fromOffsets: IndexSet(integer: source),
            toOffset: destination > source ? destination + 1 : destination
        )
        onReorder(reordered)
    }

    func performDrop(info: DropInfo) -> Bool {
        onEnd()
        return true
    }
}
#endif
