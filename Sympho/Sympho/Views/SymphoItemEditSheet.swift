//
//  SymphoItemEditSheet.swift
//  Sympho
//

import SwiftUI
import SwiftData

enum SymphoEditSubject {
    case domain(Domain)
    case track(Track)
    case module(Module)
    case node(Node)
    case project(Project)

    var sheetTitle: String {
        switch self {
        case .domain: return "Edit Domain"
        case .track: return "Edit Track"
        case .module: return "Edit Module"
        case .node: return "Edit Node"
        case .project: return "Edit Project"
        }
    }

    var showsIconPicker: Bool {
        if case .domain = self { return true }
        return false
    }

    var showsNodeStatus: Bool {
        if case .node = self { return true }
        return false
    }
}

struct SymphoItemEditSheet: View {
    @Environment(\.modelContext) private var modelContext

    let subject: SymphoEditSubject
    var onDismiss: () -> Void

    @State private var title = ""
    @State private var desc = ""
    @State private var icon: DomainIcon = .book
    @State private var nodeStatus: NodeStatus = .backlog

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerPreview

            VStack(alignment: .leading, spacing: 14) {
                SymphoEditorField(title: "NAME") {
                    TextField(namePlaceholder, text: $title)
                        .textFieldStyle(.plain)
                }

                if case .node(let node) = subject {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("NOTES")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(SymphoTheme.tertiaryText)

                        MarkdownNoteEditor(text: $desc, documentId: node.id.uuidString)
                            .frame(minHeight: 180)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(SymphoTheme.elevatedCanvas.opacity(0.72))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                            }
                    }
                } else {
                    SymphoEditorField(title: "DESCRIPTION") {
                        TextField("Optional description…", text: $desc, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(2...4)
                    }
                }

                if subject.showsNodeStatus {
                    SymphoEditorField(title: "STATUS") {
                        Picker("Status", selection: $nodeStatus) {
                            ForEach(NodeStatus.allCases) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                }
            }

            if subject.showsIconPicker {
                iconPicker
            }

            HStack {
                Spacer()
                Button("Cancel", action: onDismiss)
                    .buttonStyle(SymphoSecondaryButtonStyle())
                Button("Save", action: save)
                    .buttonStyle(SymphoPrimaryButtonStyle())
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .background(SymphoTheme.primaryCanvas)
        .onAppear(perform: loadDrafts)
        #if os(macOS)
        .frame(width: subject.showsIconPicker ? 470 : (subject.showsNodeStatus ? 480 : 420))
        .frame(minHeight: subject.showsNodeStatus ? 520 : nil)
        #endif
    }

    private var namePlaceholder: String {
        switch subject {
        case .domain: return "Domain name"
        case .track: return "Track title"
        case .module: return "Module title"
        case .node: return "Node title"
        case .project: return "Project title"
        }
    }

    @ViewBuilder
    private var headerPreview: some View {
        HStack(alignment: .top, spacing: 14) {
            if subject.showsIconPicker {
                Image(systemName: icon.rawValue)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular, in: .rect(cornerRadius: 15))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(subject.sheetTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)

                Text("Update how this appears across Sympho.")
                    .font(.system(size: 12))
                    .foregroundStyle(SymphoTheme.secondaryText)
            }
        }
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ICON")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SymphoTheme.tertiaryText)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                ForEach(DomainIcon.allCases) { option in
                    Button {
                        icon = option
                    } label: {
                        Image(systemName: option.rawValue)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(SymphoTheme.primaryText)
                            .frame(width: 44, height: 36)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(icon == option ? SymphoTheme.elevatedCanvas : SymphoTheme.secondarySurface.opacity(0.5))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(icon == option ? SymphoTheme.primaryText.opacity(0.24) : SymphoTheme.dividerColor, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .help(option.displayName)
                }
            }
        }
    }

    private func loadDrafts() {
        switch subject {
        case .domain(let domain):
            title = domain.title
            desc = domain.desc
            icon = DomainIcon(rawValue: domain.iconName) ?? .book
        case .track(let track):
            title = track.title
            desc = track.desc
        case .module(let module):
            title = module.title
            desc = module.desc
        case .node(let node):
            title = node.title
            desc = node.desc
            nodeStatus = node.status
        case .project(let project):
            title = project.title
            desc = project.desc
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        switch subject {
        case .domain(let domain):
            domain.title = trimmedTitle
            domain.desc = desc.trimmingCharacters(in: .whitespacesAndNewlines)
            domain.iconName = icon.rawValue
            markDirty(domain)
        case .track(let track):
            track.title = trimmedTitle
            track.desc = desc.trimmingCharacters(in: .whitespacesAndNewlines)
            track.updatedAt = Date()
            if let domain = track.domain { markDirty(domain) }
        case .module(let module):
            module.title = trimmedTitle
            module.desc = desc.trimmingCharacters(in: .whitespacesAndNewlines)
            module.updatedAt = Date()
            if let domain = module.domain ?? module.track?.domain { markDirty(domain) }
        case .node(let node):
            node.title = trimmedTitle
            node.desc = desc.trimmingCharacters(in: .whitespacesAndNewlines)
            node.status = nodeStatus
            node.updatedAt = Date()
            if let domain = node.module?.domain ?? node.module?.track?.domain ?? node.project?.domain {
                markDirty(domain)
            }
        case .project(let project):
            project.title = trimmedTitle
            project.desc = desc.trimmingCharacters(in: .whitespacesAndNewlines)
            project.updatedAt = Date()
            project.isSynced = false
            if let domain = project.domain { markDirty(domain) }
        }

        try? modelContext.save()
        onDismiss()
    }

    private func markDirty(_ domain: Domain) {
        domain.updatedAt = Date()
        domain.isSynced = false
    }
}

struct SymphoEditorField<Content: View>: View {
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

/// Circular liquid-glass overflow menu — Edit and optional Delete.
struct SymphoOverflowMenu: View {
    var help: String = "More actions"
    var size: CGFloat = 36
    var iconSize: CGFloat = 14
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    init(onEdit: @escaping () -> Void, onDelete: (() -> Void)? = nil) {
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    var body: some View {
        Menu {
            if let onEdit {
                Button("Edit", systemImage: "pencil", action: onEdit)
            }
            if let onDelete {
                Button("Delete", role: .destructive, action: onDelete)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: iconSize, weight: .semibold))
                .frame(width: size, height: size)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(help)
        .accessibilityLabel(help)
    }
}
