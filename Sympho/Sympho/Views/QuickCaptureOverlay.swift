//
//  QuickCaptureOverlay.swift
//  Sympho
//
//  Created by Tanner Fause on 30.05.2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

private struct CaptureAttachment: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var caption: String = ""
}

private struct CapturePreviewChip: View {
    let icon: String
    let title: String
    let subtitle: String?
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SymphoTheme.secondaryText)
                .frame(width: 28, height: 28)
                .background(SymphoTheme.elevatedCanvas, in: .rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: 148, alignment: .leading)

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                }
                .buttonStyle(.plain)
                .help("Remove")
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 7)
        .background(SymphoTheme.elevatedCanvas.opacity(0.9), in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        }
    }
}

struct QuickCaptureOverlay: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Binding var isPresented: Bool
    var initialIntent: CaptureIntent?
    var initialRoute: CaptureRoute?

    @State private var textInput: String = ""
    @State private var captureIntent: CaptureIntent = .planInbox
    @State private var route: CaptureRoute = .inbox
    @State private var attachedFiles: [CaptureAttachment] = []
    @State private var isDropTargetActive = false
    @State private var isShowingFileImporter = false
    @State private var importErrorMessage: String?

    @Query(
        filter: #Predicate<Domain> { !$0.isArchived && !$0.isDeletedLocally },
        sort: [SortDescriptor(\Domain.sortIndex), SortDescriptor(\Domain.title)]
    )
    private var domains: [Domain]

    @Query(filter: #Predicate<Project> { !$0.isDeletedLocally }, sort: \Project.title)
    private var projects: [Project]

    private var hasText: Bool {
        !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasPreviews: Bool {
        !attachedFiles.isEmpty || pastedLinkPreview != nil
    }

    init(
        isPresented: Binding<Bool>,
        initialIntent: CaptureIntent? = nil,
        initialRoute: CaptureRoute? = nil
    ) {
        _isPresented = isPresented
        self.initialIntent = initialIntent
        self.initialRoute = initialRoute
        _captureIntent = State(initialValue: initialIntent ?? .planInbox)
        _route = State(initialValue: initialIntent == .planInbox ? .inbox : (initialRoute ?? .inbox))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 12) {
                if hasPreviews {
                    previewStrip
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                TextEditor(text: $textInput)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: hasPreviews ? 88 : 112)
                    .overlay(alignment: .topLeading) {
                        if !hasText {
                            Text(captureIntent.placeholder)
                                .font(.system(size: 13))
                                .foregroundStyle(SymphoTheme.tertiaryText)
                                .padding(.top, 1)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .animation(.spring(response: 0.32, dampingFraction: 0.84), value: hasPreviews)

            fileDropZone
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            actionBar
        }
        .background(SymphoTheme.primaryCanvas)
        #if os(macOS)
        .frame(width: 560, height: 430)
        #endif
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: LibraryFileClassifier.importableContentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                addFiles(urls)
            case .failure(let error):
                importErrorMessage = error.localizedDescription
            }
        }
        .onChange(of: captureIntent) { _, newIntent in
            if newIntent.showsDestinationPicker {
                let configuredRoute = MenuBarCaptureSettings.suggestedDefaultRoute(domains: domains, projects: projects)
                route = configuredRoute.isValid ? configuredRoute : .inbox
            } else {
                route.selectInbox()
            }
        }
        .alert("Some files could not be saved", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )) {
            Button("OK") {
                importErrorMessage = nil
            }
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            Text("Quick Capture")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SymphoTheme.primaryText)

            Spacer()

            CaptureIntentPicker(intent: $captureIntent)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var previewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let link = pastedLinkPreview {
                    CapturePreviewChip(
                        icon: linkResourceType(for: link).iconName,
                        title: urlHost(from: link),
                        subtitle: "Link in text",
                        onRemove: nil
                    )
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }

                ForEach(attachedFiles) { attachment in
                    CapturePreviewChip(
                        icon: fileIcon(for: attachment.url),
                        title: attachment.url.lastPathComponent,
                        subtitle: fileSizeLabel(for: attachment.url),
                        onRemove: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                attachedFiles.removeAll { $0.id == attachment.id }
                            }
                        }
                    )
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var fileDropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: isDropTargetActive ? "arrow.down.circle.fill" : "arrow.down.doc")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(isDropTargetActive ? SymphoTheme.primaryText : SymphoTheme.tertiaryText)
                .symbolEffect(.bounce, value: isDropTargetActive)

            Text(isDropTargetActive ? "Release to attach" : dropZoneTitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isDropTargetActive ? SymphoTheme.primaryText : SymphoTheme.secondaryText)

            Button("Choose Files…") {
                isShowingFileImporter = true
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(SymphoTheme.primaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: attachedFiles.isEmpty ? 104 : 80)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isDropTargetActive ? SymphoTheme.elevatedCanvas : SymphoTheme.elevatedCanvas.opacity(0.55))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isDropTargetActive ? SymphoTheme.primaryText.opacity(0.45) : SymphoTheme.dividerColor,
                    style: StrokeStyle(
                        lineWidth: isDropTargetActive ? 2 : 1,
                        dash: isDropTargetActive ? [] : [6, 4]
                    )
                )
        }
        .scaleEffect(isDropTargetActive ? 1.015 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isDropTargetActive)
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: attachedFiles.count)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargetActive) { providers in
            handleDrop(providers)
        }
    }

    private var dropZoneTitle: String {
        if attachedFiles.isEmpty {
            return "Drop files here"
        }
        return "Drop more files here"
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            if captureIntent.showsDestinationPicker {
                HStack(spacing: 6) {
                    Text("Destination")
                        .font(.system(size: 12))
                        .foregroundStyle(SymphoTheme.secondaryText)

                    CaptureDestinationPicker(
                        route: $route,
                        domains: domains,
                        projects: projects
                    )
                }
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(SymphoSecondaryButtonStyle())
            .keyboardShortcut(.cancelAction)

            Button("Capture") {
                capture()
            }
            .buttonStyle(SymphoPrimaryButtonStyle())
            .disabled(!canCapture)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(SymphoTheme.elevatedCanvas.opacity(0.35))
    }

    private var canCapture: Bool {
        let hasContent = hasText || !attachedFiles.isEmpty
        guard hasContent else { return false }
        if captureIntent == .planInbox { return true }
        return route.isValid
    }

    private var pastedLinkPreview: String? {
        let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let links = detectedLinks(in: trimmed)
        guard links.count == 1, trimmed == links[0] || trimmed == links[0].trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        return links[0]
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var urls: [URL] = []

        for provider in providers {
            group.enter()
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                defer { group.leave() }
                guard
                    let data,
                    let string = String(data: data, encoding: .utf8),
                    let url = URL(string: string)
                else {
                    return
                }
                urls.append(url)
            }
        }

        group.notify(queue: .main) {
            addFiles(urls)
        }
        return true
    }

    private func fileIcon(for url: URL) -> String {
        LibraryFileClassifier.iconName(forFile: url)
    }

    private func fileSizeLabel(for url: URL) -> String? {
        LibraryFileClassifier.fileSizeLabel(for: url)
    }

    private func detectResourceType(for url: URL) -> ResourceType {
        LibraryFileClassifier.resourceType(forFile: url)
    }

    private func linkResourceType(for link: String) -> ResourceType {
        let lower = link.lowercased()
        if lower.contains("youtube.com") || lower.contains("youtu.be") || lower.contains("vimeo.com") {
            return .video
        }
        return .url
    }

    private func addFiles(_ urls: [URL]) {
        let existingPaths = Set(attachedFiles.map { $0.url.standardizedFileURL.path })
        let newAttachments = urls
            .filter { $0.isFileURL }
            .filter { !existingPaths.contains($0.standardizedFileURL.path) }
            .map { CaptureAttachment(url: $0) }

        guard !newAttachments.isEmpty else { return }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            attachedFiles.append(contentsOf: newAttachments)
        }
    }

    private func capture() {
        let input = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty || !attachedFiles.isEmpty else { return }
        guard canCapture else { return }

        let nodeTitle = captureTitle(from: input)
        let effectiveRoute: CaptureRoute = captureIntent == .planInbox ? .inbox : route

        let node = Node(
            title: nodeTitle,
            desc: input.isEmpty ? defaultDescription : input,
            isOrphan: effectiveRoute.isInbox,
            captureIntent: captureIntent
        )

        modelContext.insert(node)
        CaptureRouting.apply(route: effectiveRoute, to: node, context: modelContext)

        var failedFiles: [String] = []
        let destinationDomain = effectiveRoute.domain ?? effectiveRoute.project?.domain

        for attachmentDraft in attachedFiles {
            let fileURL = attachmentDraft.url
            let parseType = detectResourceType(for: fileURL)
            let res = Resource(
                title: fileURL.lastPathComponent,
                bodyText: attachmentDraft.caption.trimmingCharacters(in: .whitespacesAndNewlines),
                resourceType: parseType,
                domain: destinationDomain
            )

            let attachment: LibraryAttachment
            do {
                let imported = try LibraryStorage.importFile(from: fileURL, entryID: res.id, entryTitle: nodeTitle)
                attachment = LibraryAttachment(imported: imported, resource: res)
            } catch {
                failedFiles.append("\(fileURL.lastPathComponent): \(error.localizedDescription)")
                continue
            }

            modelContext.insert(res)
            modelContext.insert(attachment)
            res.attachments.append(attachment)
            node.resources.append(res)

            if let proj = effectiveRoute.project {
                proj.resources.append(res)
            }
        }

        for link in detectedLinks(in: input) {
            let parseType = linkResourceType(for: link)
            let res = Resource(
                title: "Source: \(urlHost(from: link))",
                urlString: link,
                resourceType: parseType,
                domain: destinationDomain
            )
            modelContext.insert(res)
            node.resources.append(res)

            if let proj = effectiveRoute.project {
                proj.resources.append(res)
            }
        }

        for resource in node.resources {
            resource.isSynced = false
        }

        try? modelContext.save()

        textInput = ""
        attachedFiles = []
        if failedFiles.isEmpty {
            isPresented = false
            dismiss()
        } else {
            importErrorMessage = "The capture was saved, but Sympho could not copy: \(failedFiles.joined(separator: ", "))."
        }
    }

    private var defaultDescription: String {
        switch captureIntent {
        case .planInbox:
            return ""
        case .learningMaterial:
            return "Learning material"
        case .learningNode:
            return "Learning node"
        }
    }

    private func urlHost(from string: String) -> String {
        guard let url = URL(string: string), let host = url.host else {
            return string
        }
        return host
    }

    private func captureTitle(from input: String) -> String {
        guard !input.isEmpty else {
            if attachedFiles.count == 1 {
                return attachedFiles[0].url.deletingPathExtension().lastPathComponent
            }

            let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
            return "Captured Files (\(dateString))"
        }

        let firstLine = input
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? input

        if firstLine.count <= 80 {
            return firstLine
        }

        return String(firstLine.prefix(77)) + "..."
    }

    private func detectedLinks(in input: String) -> [String] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        var links: [String] = []
        detector.enumerateMatches(in: input, options: [], range: range) { result, _, _ in
            guard let urlString = result?.url?.absoluteString else { return }
            if !links.contains(urlString) {
                links.append(urlString)
            }
        }
        return links
    }
}
