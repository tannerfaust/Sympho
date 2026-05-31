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
#endif

private enum LibraryFilterScope: String, CaseIterable, Identifiable {
    case domains
    case projects

    var id: String { rawValue }

    var title: String {
        switch self {
        case .domains: return "Domains"
        case .projects: return "Projects"
        }
    }
}

struct LibraryView: View {
    @Query(filter: #Predicate<Resource> { !$0.isDeletedLocally }, sort: \Resource.updatedAt, order: .reverse)
    private var entries: [Resource]

    @Query(
        filter: #Predicate<Domain> { !$0.isArchived && !$0.isDeletedLocally },
        sort: [SortDescriptor(\Domain.sortIndex), SortDescriptor(\Domain.title)]
    )
    private var domains: [Domain]

    @Query(filter: #Predicate<Project> { !$0.isDeletedLocally }, sort: \Project.title)
    private var projects: [Project]

    @State private var selectedEntry: Resource?
    @State private var searchText = ""
    @State private var filterScope: LibraryFilterScope = .domains
    @State private var selectedDomain: Domain?
    @State private var selectedProject: Project?
    @State private var showsCreateEntry = false
    @State private var showsWorkspacePicker = false
    @State private var showsCompactTitle = false
    @State private var workspaceName = LibraryStorage.workspaceName

    var body: some View {
        if let selectedEntry {
            LibraryEntryDetailView(entry: selectedEntry) {
                self.selectedEntry = nil
            }
        } else {
            overview
        }
    }

    private var overview: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                searchBar
                filterBar

                if filteredEntries.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 290), spacing: 14)], spacing: 14) {
                        ForEach(filteredEntries) { entry in
                            LibraryEntryCard(entry: entry) {
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
            CreateLibraryEntrySheet(domains: domains)
        }
        .fileImporter(
            isPresented: $showsWorkspacePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let folder = urls.first else { return }
            if (try? LibraryStorage.setWorkspace(folder)) != nil {
                workspaceName = LibraryStorage.workspaceName
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Library")
                    .editorialHeader()

                Text(entries.isEmpty ? "No saved entries" : "\(entries.count) saved entr\(entries.count == 1 ? "y" : "ies")")
                    .metadataSans()
            }

            Spacer()

            Menu {
                Button {
                    showsWorkspacePicker = true
                } label: {
                    Label("Choose Library Folder", systemImage: "folder")
                }

                if workspaceName != nil {
                    Button {
                        LibraryStorage.clearWorkspace()
                        workspaceName = nil
                    } label: {
                        Label("Use Internal Storage", systemImage: "internaldrive")
                    }
                }
            } label: {
                Image(systemName: workspaceName == nil ? "internaldrive" : "folder")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .help(workspaceName.map { "Library Folder: \($0)" } ?? "Library Storage")

            Button {
                showsCreateEntry = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help("New Library Entry")
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
        .librarySurface()
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

            if filterScope == .domains {
                domainFilters
            } else {
                projectFilters
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

    private var filteredEntries: [Resource] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return entries.filter {
            let matchesSearch = query.isEmpty ||
                $0.title.lowercased().contains(query) ||
                $0.bodyText.lowercased().contains(query) ||
                $0.urlString.lowercased().contains(query) ||
                $0.attachments.contains { $0.displayName.lowercased().contains(query) }

            guard matchesSearch else { return false }

            switch filterScope {
            case .domains:
                guard let selectedDomain else { return true }
                return $0.domain?.id == selectedDomain.id ||
                    $0.nodes.contains { node in
                        node.module?.track?.domain?.id == selectedDomain.id ||
                        node.module?.domain?.id == selectedDomain.id
                    } ||
                    $0.projects.contains { $0.domain?.id == selectedDomain.id }
            case .projects:
                guard let selectedProject else { return true }
                return $0.projects.contains { $0.id == selectedProject.id } ||
                    $0.nodes.contains { $0.project?.id == selectedProject.id }
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
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .frame(width: 42, height: 42)
                        .glassEffect(.regular, in: .rect(cornerRadius: 13))

                    Spacer()

                    if attachmentCount > 0 {
                        Label("\(attachmentCount)", systemImage: "paperclip")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(SymphoTheme.tertiaryText)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .lineLimit(1)

                    Text(summaryText)
                        .font(.system(size: 12))
                        .foregroundStyle(SymphoTheme.secondaryText)
                        .lineLimit(3)
                        .frame(minHeight: 44, alignment: .topLeading)
                }

                HStack(spacing: 8) {
                    if let domain = entry.domain {
                        Label(domain.title, systemImage: DomainIcon.validated(domain.iconName))
                            .lineLimit(1)
                    }

                    Spacer()
                    Text(entry.updatedAt, style: .relative)
                }
                .font(.system(size: 10))
                .foregroundStyle(SymphoTheme.tertiaryText)
            }
            .padding(15)
            .frame(minHeight: 175, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(SymphoTheme.elevatedCanvas.opacity(isHovering ? 0.86 : 0.62))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(isHovering ? SymphoTheme.primaryText.opacity(0.16) : SymphoTheme.dividerColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Delete Entry", role: .destructive) {
                entry.isDeletedLocally = true
                entry.updatedAt = Date()
                entry.isSynced = false
                try? modelContext.save()
            }
        }
    }

    private var attachmentCount: Int {
        entry.attachments.count + (entry.fileRelativePath == nil ? 0 : 1)
    }

    private var iconName: String {
        if attachmentCount > 1 { return "doc.on.doc" }
        if attachmentCount == 1 { return "paperclip" }
        return entry.resourceType.iconName
    }

    private var summaryText: String {
        if !entry.bodyText.isEmpty { return entry.bodyText }
        if !entry.urlString.isEmpty { return entry.urlString }
        if attachmentCount > 0 { return "\(attachmentCount) attached file\(attachmentCount == 1 ? "" : "s")" }
        return "Saved reference entry"
    }
}

private struct LibraryEntryDetailView: View {
    @Environment(\.openURL) private var openURL

    let entry: Resource
    let onBack: () -> Void

    @State private var showsCompactTitle = false
    @State private var selectedImage: LibraryImagePreview?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                detailHeader

                if !entry.bodyText.isEmpty {
                    Text(entry.bodyText)
                        .font(.system(size: 14))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: 720, alignment: .leading)
                }

                if !entry.urlString.isEmpty && entry.fileRelativePath == nil {
                    sourceLink
                }

                attachmentsSection
            }
            .padding(.horizontal, SymphoTheme.outerPadding)
            .padding(.top, 16)
            .padding(.bottom, SymphoTheme.outerPadding)
        }
        .libraryScrollChrome(title: entry.title, showsCompactTitle: $showsCompactTitle)
        .sheet(item: $selectedImage) { preview in
            LibraryImageViewer(preview: preview)
        }
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help("Back to Library")

            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .frame(width: 54, height: 54)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.title)
                        .editorialHeader()

                    HStack(spacing: 12) {
                        if let domain = entry.domain {
                            Label(domain.title, systemImage: DomainIcon.validated(domain.iconName))
                        }
                        Text("\(attachments.count) file\(attachments.count == 1 ? "" : "s")")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(SymphoTheme.secondaryText)
                }
            }
        }
    }

    private var sourceLink: some View {
        Button {
            guard let url = normalizedURL else { return }
            openURL(url)
        } label: {
            Label(entry.urlString, systemImage: "link")
                .font(.system(size: 12))
                .foregroundStyle(SymphoTheme.secondaryText)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], spacing: 12) {
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
        var result = entry.attachments.map {
            LibraryDisplayAttachment(
                id: $0.id,
                name: $0.displayName,
                contentType: $0.contentType,
                url: LibraryStorage.resolvedURL(for: $0)
            )
        }

        if let legacyURL = LibraryStorage.legacyResolvedURL(for: entry) {
            result.append(
                LibraryDisplayAttachment(
                    id: entry.id,
                    name: legacyURL.lastPathComponent,
                    contentType: UTType(filenameExtension: legacyURL.pathExtension)?.identifier ?? UTType.data.identifier,
                    url: legacyURL
                )
            )
        }

        return result
    }

    private func open(_ attachment: LibraryDisplayAttachment) {
        guard let url = attachment.url else { return }
        if attachment.isImage {
            selectedImage = LibraryImagePreview(url: url, title: attachment.name)
        } else {
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
}

private struct LibraryAttachmentCard: View {
    let attachment: LibraryDisplayAttachment
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                preview

                Label(attachment.name, systemImage: attachment.isImage ? "photo" : "doc")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(1)
            }
            .padding(11)
            .librarySurface()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var preview: some View {
        if attachment.isImage, let url = attachment.url {
            LibraryLocalImage(url: url)
                .aspectRatio(contentMode: .fill)
                .frame(height: 132)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Image(systemName: "doc")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(SymphoTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 132)
                .background(SymphoTheme.secondarySurface.opacity(0.55), in: .rect(cornerRadius: 10))
        }
    }
}

private struct CreateLibraryEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let domains: [Domain]

    @State private var title = ""
    @State private var bodyText = ""
    @State private var sourceURL = ""
    @State private var selectedDomain: Domain?
    @State private var selectedFiles: [URL] = []
    @State private var showsFileImporter = false

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
            allowedContentTypes: [.data, .content, .image, .pdf],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            selectedFiles.append(contentsOf: urls.filter { !selectedFiles.contains($0) })
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

            TextEditor(text: $bodyText)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(height: 104)
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
        modelContext.insert(entry)

        for file in selectedFiles {
            guard let imported = try? LibraryStorage.importFile(from: file, entryID: entry.id) else { continue }
            let attachment = LibraryAttachment(
                displayName: imported.displayName,
                storedPath: imported.storedPath,
                storageKind: imported.storageKind,
                contentType: imported.contentType,
                resource: entry
            )
            modelContext.insert(attachment)
            entry.attachments.append(attachment)
        }

        try? modelContext.save()
        dismiss()
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
    let url: URL?

    var isImage: Bool {
        UTType(contentType)?.conforms(to: .image) == true
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

    var body: some View {
        #if os(macOS)
        if let data = LibraryStorage.data(at: url), let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
        } else {
            fallback
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
}
