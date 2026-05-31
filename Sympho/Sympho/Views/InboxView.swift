//
//  InboxView.swift
//  Sympho
//
//  Created by Tanner Fause on 30.05.2026.
//

import SwiftUI
import SwiftData

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
    @State private var selectedNodeForTriage: Node?
    @State private var showsCompactTitle = false

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
        .sheet(item: $selectedNodeForTriage) { node in
            TriageDestinationSheet(node: node, domains: domains, projects: projects)
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
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Inbox")
                        .editorialHeader()

                    Text(orphanNodes.isEmpty ? "No captures waiting" : "\(orphanNodes.count) waiting to be filed")
                        .metadataSans()
                }

                Spacer()
            }

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
        LazyVStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Unsorted")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)

                Text("\(orphanNodes.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background {
                        Capsule()
                            .fill(SymphoTheme.elevatedCanvas.opacity(0.72))
                    }

                Spacer()

                Text("Newest first")
                    .font(.system(size: 11))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }
            .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(orphanNodes) { node in
                    InboxCaptureRow(node: node) {
                        selectedNodeForTriage = node
                    }

                    if node.id != orphanNodes.last?.id {
                        MinimalDivider()
                            .padding(.leading, 58)
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SymphoTheme.elevatedCanvas.opacity(0.5))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SymphoTheme.dividerColor, lineWidth: 1)
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
        .padding(.bottom, SymphoTheme.outerPadding)
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
            isOrphan: true
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
    var onFile: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: resourceIcon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SymphoTheme.secondaryText)
                .frame(width: 38, height: 38)
                .background {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(SymphoTheme.secondarySurface.opacity(0.82))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(node.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if !node.desc.isEmpty {
                        Text(node.desc)
                            .lineLimit(1)
                    } else if let url = sourceURL {
                        Text(url)
                            .lineLimit(1)
                    } else {
                        Text("Note")
                    }

                    Text("·")

                    Text(node.createdAt, style: .relative)
                }
                .font(.system(size: 11))
                .foregroundStyle(SymphoTheme.secondaryText)
            }

            Spacer(minLength: 12)

            if isHovering {
                Button(action: deleteNode) {
                    Image(systemName: "trash")
                }
                .buttonStyle(SymphoIconButtonStyle())
                .help("Delete capture")
            }

            Button(action: onFile) {
                Label("File", systemImage: "tray.and.arrow.down")
            }
            .buttonStyle(SymphoSecondaryButtonStyle())
            .help("File capture")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovering ? SymphoTheme.secondarySurface.opacity(0.82) : .clear)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onFile)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("File Capture", action: onFile)

            Divider()

            Button("Delete", role: .destructive, action: deleteNode)
        }
    }

    private var resourceIcon: String {
        node.resources.first?.resourceType.iconName ?? "note.text"
    }

    private var sourceURL: String? {
        let value = node.resources.first?.urlString ?? ""
        return value.isEmpty ? nil : value
    }

    private func deleteNode() {
        node.isDeletedLocally = true
        node.isSynced = false
        node.updatedAt = Date()
        try? modelContext.save()
    }
}

private struct TriageDestinationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let node: Node
    let domains: [Domain]
    let projects: [Project]

    @State private var destination: InboxDestination = .domain
    @State private var selectedDomain: Domain?
    @State private var selectedTrack: Track?
    @State private var selectedModule: Module?
    @State private var selectedProject: Project?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            sheetHeader

            capturePreview

            Picker("Destination", selection: $destination) {
                ForEach(InboxDestination.allCases) { destination in
                    Text(destination.title).tag(destination)
                }
            }
            .pickerStyle(.segmented)

            if destination == .domain {
                domainAssignment
            } else {
                projectAssignment
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(SymphoSecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("File Capture") {
                    applyTriage()
                }
                .buttonStyle(SymphoPrimaryButtonStyle())
                .disabled(isConfirmDisabled)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .background(SymphoTheme.primaryCanvas)
        #if os(macOS)
        .frame(width: 500)
        #endif
    }

    private var sheetHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(SymphoTheme.primaryText)
                .frame(width: 50, height: 50)
                .glassEffect(.regular, in: .rect(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 5) {
                Text("File Capture")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)

                Text("Place this capture where it belongs so it can become part of an active learning path or project.")
                    .font(.system(size: 12))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var capturePreview: some View {
        HStack(spacing: 12) {
            Image(systemName: node.resources.first?.resourceType.iconName ?? "note.text")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SymphoTheme.secondaryText)
                .frame(width: 34, height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(SymphoTheme.secondarySurface.opacity(0.82))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(node.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(1)

                Text(node.desc.isEmpty ? "Inbox capture" : node.desc)
                    .font(.system(size: 11))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(11)
        .background {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(SymphoTheme.elevatedCanvas.opacity(0.62))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        }
    }

    private var domainAssignment: some View {
        VStack(alignment: .leading, spacing: 10) {
            AssignmentPickerRow(title: "Domain", iconName: "books.vertical") {
                Picker("Domain", selection: $selectedDomain) {
                    Text("Choose a domain").tag(nil as Domain?)

                    ForEach(domains) { domain in
                        Text(domain.title).tag(domain as Domain?)
                    }
                }
                .labelsHidden()
                .onChange(of: selectedDomain) {
                    selectedTrack = nil
                    selectedModule = nil
                }
            }

            if let domain = selectedDomain {
                AssignmentPickerRow(title: "Track", iconName: "square.stack.3d.up") {
                    Picker("Track", selection: $selectedTrack) {
                        Text("Standalone modules").tag(nil as Track?)

                        ForEach(domain.tracks.filter { !$0.isDeletedLocally }) { track in
                            Text(track.title).tag(track as Track?)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedTrack) {
                        selectedModule = nil
                    }
                }

                AssignmentPickerRow(title: "Module", iconName: "rectangle.stack") {
                    Picker("Module", selection: $selectedModule) {
                        Text("Choose a module").tag(nil as Module?)

                        ForEach(availableModules) { module in
                            Text(module.title).tag(module as Module?)
                        }
                    }
                    .labelsHidden()
                }
            }
        }
    }

    private var projectAssignment: some View {
        AssignmentPickerRow(title: "Project", iconName: "folder") {
            Picker("Project", selection: $selectedProject) {
                Text("Choose a project").tag(nil as Project?)

                ForEach(projects) { project in
                    Text(project.title).tag(project as Project?)
                }
            }
            .labelsHidden()
        }
    }

    private var availableModules: [Module] {
        if let selectedTrack {
            return selectedTrack.modules.filter { !$0.isDeletedLocally }
        }

        return selectedDomain?.modules.filter { !$0.isDeletedLocally && $0.track == nil } ?? []
    }

    private var isConfirmDisabled: Bool {
        switch destination {
        case .domain:
            return selectedDomain == nil || selectedModule == nil
        case .project:
            return selectedProject == nil
        }
    }

    private func applyTriage() {
        switch destination {
        case .domain:
            guard let module = selectedModule else { return }
            node.module = module
            node.isOrphan = false
            node.isSynced = false

            if let resource = node.resources.first {
                resource.domain = selectedDomain
                resource.isSynced = false
            }
        case .project:
            guard let project = selectedProject else { return }
            node.project = project
            node.isOrphan = false
            node.isSynced = false

            if let resource = node.resources.first {
                project.resources.append(resource)
                project.isSynced = false
                resource.isSynced = false
            }
        }

        node.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}

private struct AssignmentPickerRow<Content: View>: View {
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

            Spacer()

            content
                .frame(maxWidth: 260, alignment: .trailing)
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
}

private enum InboxDestination: String, CaseIterable, Identifiable {
    case domain
    case project

    var id: String { rawValue }

    var title: String {
        switch self {
        case .domain: return "Domain"
        case .project: return "Project"
        }
    }
}
