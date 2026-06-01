//
//  QuickCaptureOverlay.swift
//  Sympho
//
//  Created by Tanner Fause on 30.05.2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct QuickCaptureOverlay: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Binding var isPresented: Bool
    
    @State private var textInput: String = ""
    @State private var routingType: String = "inbox" // "inbox", "domain", "project"
    @State private var selectedDomain: Domain? = nil
    @State private var selectedProject: Project? = nil
    @State private var attachedFiles: [URL] = []
    @State private var isDraggingOver = false
    @State private var importErrorMessage: String?
    
    // Fetch options for routing
    @Query(
        filter: #Predicate<Domain> { !$0.isArchived && !$0.isDeletedLocally },
        sort: [SortDescriptor(\Domain.sortIndex), SortDescriptor(\Domain.title)]
    )
    private var domains: [Domain]
    
    @Query(filter: #Predicate<Project> { !$0.isDeletedLocally }, sort: \Project.title)
    private var projects: [Project]
    
    // Smart Parsing Properties based on input text
    private var detectedType: ResourceType {
        let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            if trimmed.contains("youtube.com") || trimmed.contains("youtu.be") || trimmed.contains("vimeo.com") {
                return .video
            }
            return .url
        }
        return .note
    }
    
    private var selectedDestinationLabel: String {
        switch routingType {
        case "inbox":
            return "Inbox"
        case "domain":
            return selectedDomain?.title ?? "Select Domain"
        case "project":
            return selectedProject?.title ?? "Select Project"
        default:
            return "Inbox"
        }
    }
    
    private var selectedDestinationIcon: String {
        switch routingType {
        case "inbox":
            return "tray"
        case "domain":
            return DomainIcon.validated(selectedDomain?.iconName ?? "")
        case "project":
            return "folder"
        default:
            return "tray"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top Input area
            HStack(spacing: 12) {
                Image(systemName: attachedFiles.isEmpty ? detectedType.iconName : "paperclip")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(SymphoTheme.secondaryText)
                
                TextField("Capture note/URL or drop files here...", text: $textInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .regular))
                    .frame(maxWidth: .infinity)
                    .onSubmit(capture)
                
                // Detected type badge (Only shown if files list is empty to keep header clean)
                if attachedFiles.isEmpty {
                    HStack(spacing: 4) {
                        Text(detectedType.displayName.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(SymphoTheme.secondaryText)
                            .tracking(0.5)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(SymphoTheme.elevatedCanvas.opacity(0.5), in: .capsule)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 9))
                        Text("\(attachedFiles.count) ATTACHED")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(SymphoTheme.primaryText.opacity(0.1), in: .capsule)
                    .foregroundColor(SymphoTheme.primaryText)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            
            // Dynamic Growing Attached Files View
            if !attachedFiles.isEmpty {
                MinimalDivider()
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachedFiles, id: \.self) { url in
                            HStack(spacing: 6) {
                                Image(systemName: fileIcon(for: url))
                                    .font(.system(size: 11))
                                    .foregroundColor(SymphoTheme.secondaryText)
                                
                                Text(url.lastPathComponent)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(SymphoTheme.primaryText)
                                    .lineLimit(1)
                                    .frame(maxWidth: 120)
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                        attachedFiles.removeAll { $0 == url }
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(SymphoTheme.tertiaryText)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(SymphoTheme.elevatedCanvas.opacity(0.6), in: .capsule)
                            .overlay {
                                Capsule()
                                    .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
            
            MinimalDivider()
            
            // Bottom Action bar
            HStack(spacing: 12) {
                // Destination Picker Menu
                Menu {
                    Button(action: {
                        routingType = "inbox"
                        selectedDomain = nil
                        selectedProject = nil
                    }) {
                        Label("Dump to Inbox", systemImage: "tray")
                    }
                    
                    if !domains.isEmpty {
                        Section("Domains") {
                            ForEach(domains) { dom in
                                Button(action: {
                                    routingType = "domain"
                                    selectedDomain = dom
                                    selectedProject = nil
                                }) {
                                    Label(dom.title, systemImage: DomainIcon.validated(dom.iconName))
                                }
                            }
                        }
                    }
                    
                    if !projects.isEmpty {
                        Section("Projects") {
                            ForEach(projects) { proj in
                                Button(action: {
                                    routingType = "project"
                                    selectedProject = proj
                                    selectedDomain = nil
                                }) {
                                    Label(proj.title, systemImage: "folder")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedDestinationIcon)
                            .font(.system(size: 11))
                        Text(selectedDestinationLabel)
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(SymphoTheme.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(SymphoTheme.elevatedCanvas.opacity(0.5), in: .capsule)
                    .overlay {
                        Capsule()
                            .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                
                Spacer()
                
                // Keyboard hints + actions
                HStack(spacing: 8) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    
                    Button(action: capture) {
                        HStack(spacing: 4) {
                            Text("Capture")
                            Image(systemName: "return")
                                .font(.system(size: 9))
                        }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(SymphoTheme.primaryText)
                        .foregroundColor(SymphoTheme.primaryCanvas)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled((textInput.trimmingCharacters(in: .whitespaces).isEmpty && attachedFiles.isEmpty) || isRouteInvalid)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
        }
        .padding(.vertical, 8)
        #if os(macOS)
        .frame(width: 520, height: attachedFiles.isEmpty ? 116 : 162)
        #endif
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            let group = DispatchGroup()
            var urls: [URL] = []
            
            for provider in providers {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    if let url = url {
                        urls.append(url)
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.attachedFiles.append(contentsOf: urls)
                }
            }
            return true
        }
        .overlay {
            if isDraggingOver {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(SymphoTheme.primaryText.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, miterLimit: 0, dash: [6, 4], dashPhase: 0))
                    .background(Color.black.opacity(0.04).cornerRadius(16))
                    .animation(.easeInOut(duration: 0.15), value: isDraggingOver)
            }
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
    
    // MARK: - Validation & Execution
    
    private var isRouteInvalid: Bool {
        if routingType == "domain" {
            return selectedDomain == nil
        } else if routingType == "project" {
            return selectedProject == nil
        }
        return false
    }
    
    private func fileIcon(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ["pdf", "epub", "doc", "docx", "pages", "txt"].contains(ext) {
            return "doc.text.fill"
        } else if ["mp4", "mov", "m4v", "avi", "mkv"].contains(ext) {
            return "play.rectangle.fill"
        }
        return "doc.fill"
    }
    
    private func detectResourceType(for url: URL) -> ResourceType {
        let ext = url.pathExtension.lowercased()
        if ["pdf", "epub", "doc", "docx", "pages", "txt"].contains(ext) {
            return .pdf
        } else if ["mp4", "mov", "m4v", "avi", "mkv"].contains(ext) {
            return .video
        }
        return .pdf // default to document reference
    }
    
    private func capture() {
        let input = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ensure at least text or files are attached
        guard !input.isEmpty || !attachedFiles.isEmpty else { return }
        
        // Determine Node Title
        var nodeTitle = ""
        var initialNoteDesc = ""
        if !input.isEmpty {
            nodeTitle = input
            if !attachedFiles.isEmpty {
                initialNoteDesc = "Captured alongside attachments."
            }
        } else {
            let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
            nodeTitle = "Captured Files (\(dateString))"
        }
        
        // Establish parents
        var moduleDestination: Module? = nil
        var projectDestination: Project? = nil
        var isOrphanNode = true
        
        if routingType == "domain", let dom = selectedDomain {
            // Find or create a default "Quick Captures" module in this domain
            let defaultModuleName = "Inbox Captures"
            if let existingModule = dom.modules.first(where: { $0.title == defaultModuleName && !$0.isDeletedLocally }) {
                moduleDestination = existingModule
            } else {
                let newModule = Module(title: defaultModuleName, desc: "Default module for quick capture entries", domain: dom)
                modelContext.insert(newModule)
                dom.modules.append(newModule)
                moduleDestination = newModule
            }
            isOrphanNode = false
        } else if routingType == "project", let proj = selectedProject {
            projectDestination = proj
            isOrphanNode = false
        }
        
        let node = Node(
            title: nodeTitle,
            desc: initialNoteDesc.isEmpty ? "Captured via Quick HUD" : initialNoteDesc,
            isOrphan: isOrphanNode,
            module: moduleDestination,
            project: projectDestination
        )
        
        // Import and attach multiple files
        var failedFiles: [String] = []
        for fileURL in attachedFiles {
            let parseType = detectResourceType(for: fileURL)
            let res = Resource(
                title: fileURL.lastPathComponent,
                resourceType: parseType,
                domain: selectedDomain
            )

            guard let imported = try? LibraryStorage.importFile(from: fileURL, entryID: res.id, entryTitle: nodeTitle) else {
                failedFiles.append(fileURL.lastPathComponent)
                continue
            }

            let attachment = LibraryAttachment(
                displayName: imported.displayName,
                storedPath: imported.storedPath,
                storageKind: imported.storageKind,
                contentType: imported.contentType,
                resource: res
            )

            modelContext.insert(res)
            modelContext.insert(attachment)
            res.attachments.append(attachment)
            node.resources.append(res)

            if let proj = projectDestination {
                proj.resources.append(res)
            }
        }
        
        // Attach text note if it looks like a URL/video link (only if no files attached, or as an extra reference)
        if attachedFiles.isEmpty && !input.isEmpty {
            let isLink = input.lowercased().hasPrefix("http://") || input.lowercased().hasPrefix("https://")
            if isLink {
                let parseType = detectedType
                let res = Resource(
                    title: "Source: \(urlHost(from: input))",
                    urlString: input,
                    resourceType: parseType,
                    domain: selectedDomain
                )
                modelContext.insert(res)
                node.resources.append(res)
                
                if let proj = projectDestination {
                    proj.resources.append(res)
                }
            }
        }
        
        modelContext.insert(node)
        
        // Save
        try? modelContext.save()
        
        textInput = ""
        attachedFiles = []
        if failedFiles.isEmpty {
            dismiss()
        } else {
            importErrorMessage = "The capture was saved, but Sympho could not copy: \(failedFiles.joined(separator: ", "))."
        }
    }
    
    private func urlHost(from string: String) -> String {
        guard let url = URL(string: string), let host = url.host else {
            return string
        }
        return host
    }
}
