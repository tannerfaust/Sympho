//
//  InboxView.swift
//  Sympho
//
//  Created by Tanner Fause on 30.05.2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

private enum InboxSortOrder: String, CaseIterable, Identifiable {
    case newestFirst
    case oldestFirst
    case title

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newestFirst: return "Newest"
        case .oldestFirst: return "Oldest"
        case .title: return "Title"
        }
    }
}

private enum InboxTypeFilter: String, CaseIterable, Identifiable {
    case all
    case planInbox
    case learningMaterial
    case learningNode

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .planInbox: return CaptureIntent.planInbox.displayName
        case .learningMaterial: return CaptureIntent.learningMaterial.displayName
        case .learningNode: return CaptureIntent.learningNode.displayName
        }
    }

    func matches(_ node: Node) -> Bool {
        switch self {
        case .all:
            return true
        case .planInbox:
            return node.captureIntent == .planInbox
        case .learningMaterial:
            return node.captureIntent == .learningMaterial
        case .learningNode:
            return node.captureIntent == .learningNode
        }
    }
}

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<Node> { ($0.isOrphan || ($0.module == nil && $0.project == nil)) && !$0.isDeletedLocally },
        sort: \Node.createdAt,
        order: .reverse
    )
    private var orphanNodes: [Node]

    @Query(
        filter: #Predicate<Domain> { !$0.isArchived && !$0.isDeletedLocally },
        sort: [SortDescriptor(\Domain.sortIndex), SortDescriptor(\Domain.title)]
    )
    private var domains: [Domain]

    @Query(filter: #Predicate<Project> { !$0.isDeletedLocally }, sort: \Project.title)
    private var projects: [Project]

    @State private var quickCaptureText = ""
    @State private var selectedNodeForPreview: Node?
    @State private var selectedNodeIDs: Set<UUID> = []
    @State private var showsCompactTitle = false
    @State private var sortOrder: InboxSortOrder = .newestFirst
    @State private var typeFilter: InboxTypeFilter = .all

    private var isSelectionMode: Bool {
        !selectedNodeIDs.isEmpty
    }

    private var displayedNodes: [Node] {
        let filtered = orphanNodes.filter { typeFilter.matches($0) }

        switch sortOrder {
        case .newestFirst:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        case .oldestFirst:
            return filtered.sorted { $0.createdAt < $1.createdAt }
        case .title:
            return filtered.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }

    private var listControlsSummary: String {
        if typeFilter == .all {
            return sortOrder.label
        }
        return "\(typeFilter.label) · \(sortOrder.label)"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                inboxHeader

                if orphanNodes.isEmpty {
                    emptyInboxView
                } else {
                    queueView
                }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 38
        } action: { _, newValue in
            withAnimation(.easeInOut(duration: 0.16)) {
                showsCompactTitle = newValue
            }
        }
        .safeAreaBar(edge: .top, spacing: 0) {
            compactTitleBar
        }
        .sheet(item: $selectedNodeForPreview) { node in
            InboxCaptureDetailSheet(node: node, domains: domains, projects: projects)
        }
        .onChange(of: typeFilter) { _, _ in
            pruneSelectionToVisibleNodes()
        }
    }

    private var compactTitleBar: some View {
        Text("Inbox")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(SymphoTheme.primaryText)
            .opacity(showsCompactTitle ? 1 : 0)
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .offset(y: -2)
            .accessibilityHidden(!showsCompactTitle)
    }

    private var inboxHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Inbox")
                .editorialHeader()

            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SymphoTheme.tertiaryText)

                TextField("Capture a note or paste a link", text: $quickCaptureText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit(executeQuickCapture)

                Button(action: executeQuickCapture) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(quickCaptureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Capture")
            }
            .padding(.leading, 13)
            .padding(.trailing, 7)
            .frame(height: 44)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 15))
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
        .padding(.top, 18)
        .padding(.bottom, 18)
    }

    private var queueView: some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            queueToolbar
                .padding(.bottom, 4)

            if displayedNodes.isEmpty {
                Text("No captures match this filter.")
                    .font(.system(size: 13))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
            } else {
                ForEach(displayedNodes) { node in
                    InboxCaptureRow(
                        node: node,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedNodeIDs.contains(node.id),
                        onToggleSelection: { toggleSelection(for: node) },
                        onOpen: {
                            guard !isSelectionMode else { return }
                            selectedNodeForPreview = node
                        }
                    )
                }
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
        .padding(.bottom, SymphoTheme.outerPadding)
        .animation(.easeInOut(duration: 0.16), value: isSelectionMode)
    }

    @ViewBuilder
    private var queueToolbar: some View {
        if isSelectionMode {
            HStack(spacing: 10) {
                Text("\(selectedNodeIDs.count) selected")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)

                Spacer()

                Button(role: .destructive) {
                    deleteSelectedNodes()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(SymphoSecondaryButtonStyle())

                Button("Cancel") {
                    selectedNodeIDs.removeAll()
                }
                .buttonStyle(SymphoSecondaryButtonStyle())
            }
        } else if !orphanNodes.isEmpty {
            HStack {
                Spacer()

                Menu {
                    Section("Show") {
                        ForEach(InboxTypeFilter.allCases) { filter in
                            Button {
                                typeFilter = filter
                            } label: {
                                if typeFilter == filter {
                                    Label(filter.label, systemImage: "checkmark")
                                } else {
                                    Text(filter.label)
                                }
                            }
                        }
                    }

                    Section("Sort") {
                        ForEach(InboxSortOrder.allCases) { order in
                            Button {
                                sortOrder = order
                            } label: {
                                if sortOrder == order {
                                    Label(order.label, systemImage: "checkmark")
                                } else {
                                    Text(order.label)
                                }
                            }
                        }
                    }
                } label: {
                    Label(listControlsSummary, systemImage: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(SymphoTheme.secondaryText)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    private func pruneSelectionToVisibleNodes() {
        let visibleIDs = Set(displayedNodes.map(\.id))
        selectedNodeIDs = selectedNodeIDs.intersection(visibleIDs)
    }

    private func toggleSelection(for node: Node) {
        if selectedNodeIDs.contains(node.id) {
            selectedNodeIDs.remove(node.id)
        } else {
            selectedNodeIDs.insert(node.id)
        }
    }

    private func deleteSelectedNodes() {
        for node in orphanNodes where selectedNodeIDs.contains(node.id) {
            node.isDeletedLocally = true
            node.isSynced = false
            node.updatedAt = Date()
        }
        selectedNodeIDs.removeAll()
        try? modelContext.save()
    }

    private var emptyInboxView: some View {
        VStack(spacing: 13) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(SymphoTheme.secondaryText)
                .frame(width: 64, height: 64)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))

            Text("Inbox clear")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SymphoTheme.primaryText)

            Text("New captures will wait here until you file them.")
                .metadataSans()

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    private func executeQuickCapture() {
        let trimmed = quickCaptureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let isLink = trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://")
        let node = Node(
            title: isLink ? linkTitle(for: trimmed) : trimmed,
            desc: isLink ? "Captured web address" : "",
            isOrphan: true,
            captureIntent: .planInbox
        )

        if isLink {
            let resource = Resource(title: "Source Link", urlString: trimmed, resourceType: .url)
            modelContext.insert(resource)
            node.resources.append(resource)
        }

        modelContext.insert(node)
        try? modelContext.save()
        quickCaptureText = ""
    }

    private func linkTitle(for address: String) -> String {
        URL(string: address)?.host(percentEncoded: false) ?? address
    }
}

private struct InboxCaptureRow: View {
    @Environment(\.modelContext) private var modelContext

    let node: Node
    let isSelectionMode: Bool
    let isSelected: Bool
    var onToggleSelection: () -> Void
    var onOpen: () -> Void

    @State private var isHovering = false

    private var activeResources: [Resource] {
        node.resources.filter { !$0.isDeletedLocally }
    }

    private var showsRowChrome: Bool {
        isHovering || isSelectionMode
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: contentIcon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(node.captureIntent.pillForeground)
                .frame(width: 40, height: 40)
                .background(node.captureIntent.pillBackground, in: .rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 8) {
                CaptureIntentBadge(intent: node.captureIntent)

                Text(node.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(SymphoTheme.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if !isSelectionMode {
                    Button(action: deleteNode) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(SymphoIconButtonStyle())
                    .opacity(isHovering ? 1 : 0)
                    .allowsHitTesting(isHovering)
                    .help("Delete")
                }

                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? SymphoTheme.primaryText : SymphoTheme.tertiaryText)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .opacity(showsRowChrome ? 1 : 0)
                .allowsHitTesting(showsRowChrome)
                .help(isSelected ? "Deselect" : "Select")
            }
            .frame(width: 68, height: 28, alignment: .trailing)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isSelected
                        ? SymphoTheme.elevatedCanvas.opacity(0.82)
                        : SymphoTheme.elevatedCanvas.opacity(0.55)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isSelected ? SymphoTheme.primaryText.opacity(0.18) : SymphoTheme.dividerColor,
                    lineWidth: 1
                )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onToggleSelection()
            } else {
                onOpen()
            }
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            if !isSelectionMode {
                Button("Open", action: onOpen)
                Divider()
            }
            Button(isSelected ? "Deselect" : "Select") {
                onToggleSelection()
            }
            Divider()
            Button("Delete", role: .destructive, action: deleteNode)
        }
    }

    private var contentIcon: String {
        if let resource = activeResources.first {
            return resource.resourceType.iconName
        }
        return node.captureIntent.iconName
    }

    private var subtitle: String {
        if let meaningful = meaningfulDescription {
            return meaningful
        }

        if activeResources.count > 1 {
            return "\(activeResources.count) attachments"
        }

        if let resource = activeResources.first {
            if !resource.urlString.isEmpty {
                return resource.urlString
            }
            return resource.title
        }

        return ""
    }

    private var meaningfulDescription: String? {
        let trimmed = node.desc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let generic: Set<String> = [
            "Captured via Quick Capture",
            "Captured web address",
            "Learning material",
            "Learning node"
        ]
        guard !generic.contains(trimmed) else { return nil }
        return trimmed
    }

    private func deleteNode() {
        node.isDeletedLocally = true
        node.isSynced = false
        node.updatedAt = Date()
        try? modelContext.save()
    }
}

private struct InboxCaptureDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let node: Node
    let domains: [Domain]
    let projects: [Project]

    @State private var editedTitle: String
    @State private var editedNotes: String
    @State private var captureIntent: CaptureIntent
    @State private var route: CaptureRoute = .inbox
    @State private var isShowingFileImporter = false
    @State private var isAddingLink = false
    @State private var newLink = ""
    @State private var importErrorMessage: String?

    init(node: Node, domains: [Domain], projects: [Project]) {
        self.node = node
        self.domains = domains
        self.projects = projects
        _editedTitle = State(initialValue: node.title)
        _editedNotes = State(initialValue: node.desc)
        _captureIntent = State(initialValue: node.captureIntent)
    }

    private var activeResources: [Resource] {
        node.resources
            .filter { !$0.isDeletedLocally }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var canSave: Bool {
        guard hasValidTitle else { return false }
        if captureIntent.showsDestinationPicker {
            return route.isValid
        }
        return true
    }

    private var hasValidTitle: Bool {
        !editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            MinimalDivider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    captureFields
                    attachmentsSection
                    if captureIntent.showsDestinationPicker {
                        destinationSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(22)
                .animation(.easeInOut(duration: 0.2), value: captureIntent)
            }

            MinimalDivider()

            footer
        }
        .background(SymphoTheme.primaryCanvas)
        #if os(macOS)
        .frame(width: 660, height: 620)
        #endif
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                attachFiles(urls)
            case .failure(let error):
                importErrorMessage = error.localizedDescription
            }
        }
        .alert("Attachment could not be saved", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )) {
            Button("OK") { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? "")
        }
        .onChange(of: captureIntent) { _, newIntent in
            if newIntent.showsDestinationPicker {
                route.selectInbox()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                CaptureIntentBadge(intent: captureIntent)

                if activeResources.count > 0 {
                    Text("\(activeResources.count) attachment\(activeResources.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(SymphoTheme.secondaryText)
                }
            }

            Spacer()

            CaptureIntentPicker(intent: $captureIntent)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var captureFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Capture title", text: $editedTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(SymphoTheme.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(SymphoTheme.elevatedCanvas.opacity(0.55), in: .rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                }

            TextEditor(text: $editedNotes)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 118)
                .padding(8)
                .background(SymphoTheme.elevatedCanvas.opacity(0.55), in: .rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    if editedNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Notes")
                            .font(.system(size: 13))
                            .foregroundStyle(SymphoTheme.tertiaryText)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Attachments")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)

                Spacer()

                Menu {
                    Button {
                        isShowingFileImporter = true
                    } label: {
                        Label("Add Files", systemImage: "paperclip")
                    }

                    Button {
                        isAddingLink = true
                    } label: {
                        Label("Add Link", systemImage: "link")
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            if activeResources.isEmpty && !isAddingLink {
                Text("No attachments yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            } else if !activeResources.isEmpty {
                VStack(spacing: 8) {
                    ForEach(activeResources) { resource in
                        InboxCaptureAttachmentRow(resource: resource) {
                            removeResource(resource)
                        }
                    }
                }
            }

            if isAddingLink {
                HStack(spacing: 8) {
                    TextField("Paste a link", text: $newLink)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(SymphoTheme.elevatedCanvas.opacity(0.66), in: .rect(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                        }
                        .onSubmit(attachLink)

                    Button("Add") {
                        attachLink()
                    }
                    .buttonStyle(SymphoPrimaryButtonStyle())
                    .disabled(newLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        newLink = ""
                        isAddingLink = false
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel")
                }
            }
        }
    }

    private var destinationSection: some View {
        HStack(spacing: 8) {
            Text("Destination")
                .font(.system(size: 12))
                .foregroundStyle(SymphoTheme.secondaryText)

            CaptureDestinationPicker(
                route: $route,
                domains: domains,
                projects: projects
            )

            Spacer()
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button(role: .destructive) {
                deleteCapture()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(SymphoSecondaryButtonStyle())

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(SymphoSecondaryButtonStyle())
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                saveAndClose()
            }
            .buttonStyle(SymphoPrimaryButtonStyle())
            .disabled(!canSave)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 22)
        .frame(height: 62)
    }

    private func saveCapture() {
        let title = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        node.title = title
        node.desc = editedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        node.captureIntent = captureIntent
        node.updatedAt = Date()
        node.isSynced = false
        try? modelContext.save()
    }

    private func saveAndClose() {
        saveCapture()

        if captureIntent.showsDestinationPicker {
            CaptureRouting.apply(route: route, to: node, context: modelContext)

            let destinationDomain = route.domain ?? route.project?.domain
            for resource in node.resources where !resource.isDeletedLocally {
                resource.domain = destinationDomain
                resource.isSynced = false

                if let project = route.project,
                   !project.resources.contains(where: { $0.id == resource.id }) {
                    project.resources.append(resource)
                }
            }
        }

        node.updatedAt = Date()
        node.isSynced = false
        try? modelContext.save()
        dismiss()
    }

    private func attachFiles(_ urls: [URL]) {
        saveCapture()

        var failedFiles: [String] = []
        for url in urls where url.isFileURL {
            let resource = Resource(
                title: url.lastPathComponent,
                resourceType: resourceType(forFile: url),
                domain: route.domain ?? route.project?.domain
            )

            guard let imported = try? LibraryStorage.importFile(from: url, entryID: resource.id, entryTitle: node.title) else {
                failedFiles.append(url.lastPathComponent)
                continue
            }

            let attachment = LibraryAttachment(
                displayName: imported.displayName,
                storedPath: imported.storedPath,
                storageKind: imported.storageKind,
                contentType: imported.contentType,
                resource: resource
            )

            modelContext.insert(resource)
            modelContext.insert(attachment)
            resource.attachments.append(attachment)
            node.resources.append(resource)
        }

        node.updatedAt = Date()
        node.isSynced = false
        try? modelContext.save()

        if !failedFiles.isEmpty {
            importErrorMessage = "Sympho could not copy: \(failedFiles.joined(separator: ", "))."
        }
    }

    private func attachLink() {
        let trimmed = newLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let resource = Resource(
            title: "Source: \(urlHost(from: trimmed))",
            urlString: trimmed,
            resourceType: resourceType(forLink: trimmed),
            domain: route.domain ?? route.project?.domain
        )
        modelContext.insert(resource)
        node.resources.append(resource)
        node.updatedAt = Date()
        node.isSynced = false
        try? modelContext.save()

        newLink = ""
        isAddingLink = false
    }

    private func removeResource(_ resource: Resource) {
        resource.isDeletedLocally = true
        resource.isSynced = false
        node.isSynced = false
        node.updatedAt = Date()
        try? modelContext.save()
    }

    private func deleteCapture() {
        node.isDeletedLocally = true
        node.isSynced = false
        node.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }

    private func resourceType(forFile url: URL) -> ResourceType {
        let ext = url.pathExtension.lowercased()
        if ["mp4", "mov", "m4v", "avi", "mkv"].contains(ext) {
            return .video
        }
        if ["txt", "md"].contains(ext) {
            return .note
        }
        if ["html", "webloc"].contains(ext) {
            return .url
        }
        return .pdf
    }

    private func resourceType(forLink link: String) -> ResourceType {
        let lower = link.lowercased()
        if lower.contains("youtube.com") || lower.contains("youtu.be") || lower.contains("vimeo.com") {
            return .video
        }
        return .url
    }

    private func urlHost(from string: String) -> String {
        URL(string: string)?.host(percentEncoded: false) ?? string
    }
}

private struct InboxCaptureAttachmentRow: View {
    let resource: Resource
    var onDelete: () -> Void

    private var destinationURL: URL? {
        if let attachment = resource.attachments.first {
            return LibraryStorage.resolvedURL(for: attachment)
        }

        if let legacyURL = LibraryStorage.legacyResolvedURL(for: resource) {
            return legacyURL
        }

        return URL(string: resource.urlString)
    }

    private var subtitle: String {
        if !resource.bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return resource.bodyText
        }

        if !resource.attachments.isEmpty || resource.fileRelativePath != nil {
            return "Saved file"
        }

        return resource.urlString.isEmpty ? resource.resourceType.displayName : resource.urlString
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: resource.resourceType.iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(SymphoTheme.secondaryText)
                .frame(width: 44, height: 44)
                .background(SymphoTheme.elevatedCanvas.opacity(0.75), in: .rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(resource.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SymphoTheme.secondaryText)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("Remove attachment")
        }
        .padding(12)
        .background(SymphoTheme.elevatedCanvas.opacity(0.5), in: .rect(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture {
            openResource()
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        }
        .contextMenu {
            Button("Open", action: openResource)
            Button("Remove", role: .destructive, action: onDelete)
        }
        .opacity(destinationURL == nil ? 0.64 : 1)
    }

    private func openResource() {
        guard let destinationURL else { return }

        #if os(macOS)
        NSWorkspace.shared.open(destinationURL)
        #endif
    }
}
