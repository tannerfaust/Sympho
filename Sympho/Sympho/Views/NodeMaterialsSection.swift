//
//  NodeMaterialsSection.swift
//  Sympho
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct NodeMaterialsSection: View {
    @Environment(\.modelContext) private var modelContext

    let node: Node

    @State private var isAddingLink = false
    @State private var newLink = ""
    @State private var isShowingFileImporter = false
    @State private var isShowingAddSheet = false
    @State private var importErrorMessage: String?

    private var activeResources: [Resource] {
        node.resources.filter { !$0.isDeletedLocally }
    }

    private var resolvedDomain: Domain? {
        node.module?.domain ?? node.module?.track?.domain ?? node.project?.domain
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if activeResources.isEmpty && !isAddingLink {
                emptyState
            } else if !activeResources.isEmpty {
                materialsList
            }

            if isAddingLink {
                linkComposer
            }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: LibraryFileClassifier.importableContentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                attachFiles(urls)
            case .failure(let error):
                importErrorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $isShowingAddSheet) {
            AddNodeMaterialSheet(node: node, domain: resolvedDomain)
        }
        .alert("Attachment could not be saved", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )) {
            Button("OK") { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Materials")
                    .editorialSubtitle()

                Text(activeResources.isEmpty ? "Links, files, and references" : "\(activeResources.count) attached")
                    .font(.system(size: 11))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }

            Spacer(minLength: 8)

            Menu {
                Button {
                    isAddingLink = true
                } label: {
                    Label("Paste Link", systemImage: "link")
                }

                Button {
                    isShowingFileImporter = true
                } label: {
                    Label("Choose File", systemImage: "paperclip")
                }

                Button {
                    isShowingAddSheet = true
                } label: {
                    Label("Add Reference…", systemImage: "doc.badge.plus")
                }
            } label: {
                Label("Add", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SymphoTheme.secondaryText)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No materials yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SymphoTheme.primaryText)

            Text("Attach a link, PDF, image, or video to keep sources close to this node.")
                .font(.system(size: 12))
                .foregroundStyle(SymphoTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .nodeMaterialsSurface()
    }

    private var materialsList: some View {
        VStack(spacing: 0) {
            ForEach(activeResources) { resource in
                NodeMaterialRow(resource: resource) {
                    removeResource(resource)
                }

                if resource.id != activeResources.last?.id {
                    MinimalDivider()
                        .padding(.leading, 52)
                }
            }
        }
        .nodeMaterialsSurface()
    }

    private var linkComposer: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SymphoTheme.tertiaryText)

            TextField("Paste a link", text: $newLink)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
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
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SymphoTheme.tertiaryText)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Cancel")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .nodeMaterialsSurface()
    }

    private func attachLink() {
        let trimmed = newLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let resource = Resource(
            title: "Source: \(urlHost(from: trimmed))",
            urlString: trimmed,
            resourceType: resourceType(forLink: trimmed),
            domain: resolvedDomain
        )
        modelContext.insert(resource)
        node.resources.append(resource)
        markNodeChanged()

        newLink = ""
        isAddingLink = false
    }

    private func attachFiles(_ urls: [URL]) {
        var failedFiles: [String] = []

        for url in urls where url.isFileURL {
            let resource = Resource(
                title: url.lastPathComponent,
                resourceType: LibraryFileClassifier.resourceType(forFile: url),
                domain: resolvedDomain
            )

            do {
                let imported = try LibraryStorage.importFile(
                    from: url,
                    entryID: resource.id,
                    entryTitle: node.title
                )
                let attachment = LibraryAttachment(imported: imported, resource: resource)
                modelContext.insert(resource)
                modelContext.insert(attachment)
                resource.attachments.append(attachment)
                node.resources.append(resource)
            } catch {
                failedFiles.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        markNodeChanged()

        if !failedFiles.isEmpty {
            importErrorMessage = "Sympho could not copy: \(failedFiles.joined(separator: ", "))."
        }
    }

    private func removeResource(_ resource: Resource) {
        resource.isDeletedLocally = true
        resource.isSynced = false
        markNodeChanged()
    }

    private func markNodeChanged() {
        node.isSynced = false
        node.updatedAt = Date()
        try? modelContext.save()
    }

    private func resourceType(forLink link: String) -> ResourceType {
        let lower = link.lowercased()
        if lower.contains("youtube.com") || lower.contains("youtu.be") { return .video }
        if lower.hasSuffix(".pdf") { return .pdf }
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") { return .url }
        return .note
    }

    private func urlHost(from string: String) -> String {
        if let url = URL(string: string), let host = url.host, !host.isEmpty {
            return host
        }
        return string
    }
}

// MARK: - Material Row

struct NodeMaterialRow: View {
    let resource: Resource
    var onRemove: () -> Void

    @State private var selectedPreview: LibraryPreviewFile?

    private var destinationURL: URL? {
        if let attachment = resource.attachments.first {
            return LibraryStorage.resolvedURL(for: attachment)
        }
        if let legacyURL = LibraryStorage.legacyResolvedURL(for: resource) {
            return legacyURL
        }
        return URL(string: resource.urlString)
    }

    private var previewFile: LibraryPreviewFile? {
        if let attachment = resource.attachments.first,
           let url = LibraryStorage.resolvedURL(for: attachment) {
            return LibraryPreviewFile(
                id: attachment.id,
                title: attachment.displayName,
                contentType: attachment.contentType,
                url: url,
                byteSize: attachment.byteSize
            )
        }

        if let legacyURL = LibraryStorage.legacyResolvedURL(for: resource) {
            return LibraryPreviewFile(
                id: resource.id,
                title: legacyURL.lastPathComponent,
                contentType: UTType(filenameExtension: legacyURL.pathExtension)?.identifier ?? UTType.data.identifier,
                url: legacyURL,
                byteSize: nil
            )
        }

        return nil
    }

    private var subtitle: String {
        if !resource.attachments.isEmpty || resource.fileRelativePath != nil {
            return resourceTypeLabel
        }
        if resource.urlString.isEmpty {
            return resourceTypeLabel
        }
        return resource.urlString
    }

    private var resourceTypeLabel: String {
        switch resource.resourceType {
        case .pdf: return "PDF Document"
        case .url: return "Web Link"
        case .video: return "Video"
        case .note: return "Note"
        }
    }

    var body: some View {
        Button(action: openResource) {
            HStack(spacing: 12) {
                Image(systemName: resource.resourceType.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(SymphoTheme.elevatedCanvas.opacity(0.7), in: .rect(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 3) {
                    Text(resource.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(SymphoTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(resourceTypeLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .symphoCardContextMenu(delete: onRemove)
        .opacity(destinationURL == nil ? 0.7 : 1)
        .sheet(item: $selectedPreview) { preview in
            LibraryFilePreviewSheet(file: preview)
        }
    }

    private func openResource() {
        if let previewFile {
            if previewFile.isPreviewable {
                selectedPreview = previewFile
            } else {
                LibraryFileActions.openExternally(previewFile.url)
            }
            return
        }

        guard let destinationURL else { return }
        LibraryFileActions.openExternally(destinationURL)
    }
}

// MARK: - Add Material Sheet

private struct AddNodeMaterialSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let node: Node
    let domain: Domain?

    @State private var title = ""
    @State private var address = ""
    @State private var type: ResourceType = .url

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .frame(width: 50, height: 50)
                    .glassEffect(.regular, in: .rect(cornerRadius: 15))

                VStack(alignment: .leading, spacing: 5) {
                    Text("Add Material")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(SymphoTheme.primaryText)

                    Text("Name a reference and where to find it.")
                        .font(.system(size: 12))
                        .foregroundStyle(SymphoTheme.secondaryText)
                }
            }

            VStack(spacing: 10) {
                materialInputRow(title: "Name", icon: "doc") {
                    TextField("Material name", text: $title)
                        .textFieldStyle(.plain)
                }

                materialInputRow(title: "Address", icon: "link") {
                    TextField("URL or path", text: $address)
                        .textFieldStyle(.plain)
                }

                materialInputRow(title: "Type", icon: "square.stack") {
                    Picker("Type", selection: $type) {
                        ForEach(ResourceType.allCases) { resourceType in
                            Text(resourceType.displayName).tag(resourceType)
                        }
                    }
                    .labelsHidden()
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(SymphoSecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Material") { save() }
                    .buttonStyle(SymphoPrimaryButtonStyle())
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 460)
        .background(SymphoTheme.primaryCanvas)
    }

    private func materialInputRow<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SymphoTheme.secondaryText)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SymphoTheme.primaryText)
                .frame(width: 62, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 11)
        .frame(height: 42)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(SymphoTheme.elevatedCanvas.opacity(0.62))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedAddress.isEmpty else { return }

        let resource = Resource(
            title: trimmedTitle,
            urlString: trimmedAddress,
            resourceType: type,
            domain: domain
        )
        modelContext.insert(resource)
        node.resources.append(resource)
        node.isSynced = false
        node.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}

private extension View {
    func nodeMaterialsSurface() -> some View {
        background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SymphoTheme.elevatedCanvas.opacity(0.5))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        }
    }
}
