//
//  TrackModulesWorkspaceView.swift
//  Sympho
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum TrackModulesViewMode: String {
    case list
    case gallery
}

struct TrackModulesWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext

    let track: Track
    var onSelectModule: (Module) -> Void
    var onSelectNode: (Node) -> Void

    @State private var viewMode: TrackModulesViewMode = .gallery
    @State private var draggedModuleID: UUID?
    @State private var editModuleTarget: Module?
    @State private var showInlineAddModule = false
    @State private var newModuleTitle = ""

    private var modules: [Module] {
        track.activeModules
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    modeButton("Gallery", .gallery, "square.grid.2x2")
                    modeButton("List", .list, "list.bullet")
                }
                .padding(2)
                .glassEffect(.regular.interactive(), in: .capsule)

                Spacer(minLength: 0)

                Button {
                    withAnimation(.snappy(duration: 0.15)) {
                        showInlineAddModule.toggle()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .help("Add module")
            }

            if showInlineAddModule {
                inlineAddField
            }

            if modules.isEmpty {
                Text("No modules in this track yet. Tap + to add one.")
                    .font(.system(size: 12))
                    .foregroundStyle(SymphoTheme.secondaryText)
            } else {
                switch viewMode {
                case .gallery:
                    galleryView
                case .list:
                    listView
                }
            }
        }
        .sheet(item: $editModuleTarget) { module in
            SymphoItemEditSheet(subject: .module(module)) {
                editModuleTarget = nil
            }
        }
    }

    private var inlineAddField: some View {
        HStack(spacing: 8) {
            TextField("Module title…", text: $newModuleTitle, onCommit: saveNewModule)
                .textFieldStyle(.plain)
                .padding(.horizontal, 11)
                .frame(height: 38)
                .background {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(SymphoTheme.elevatedCanvas.opacity(0.58))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                }

            Button("Add", action: saveNewModule)
                .buttonStyle(SymphoPrimaryButtonStyle())
        }
        .transition(.opacity)
    }

    private func saveNewModule() {
        let title = newModuleTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let nextIndex = modules.map(\.sortIndex).max().map { $0 + 1 } ?? 0
        let newModule = Module(title: title, desc: "", sortIndex: nextIndex, track: track)
        modelContext.insert(newModule)
        track.modules.append(newModule)
        track.updatedAt = Date()
        track.isSynced = false
        if let domain = track.domain {
            domain.updatedAt = Date()
            domain.isSynced = false
        }
        try? modelContext.save()

        newModuleTitle = ""
        showInlineAddModule = false
    }

    private func modeButton(_ title: String, _ mode: TrackModulesViewMode, _ icon: String) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) { viewMode = mode }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(viewMode == mode ? SymphoTheme.primaryCanvas : SymphoTheme.secondaryText)
            .background {
                if viewMode == mode {
                    Capsule().fill(SymphoTheme.primaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var galleryView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
            ForEach(modules) { module in
                DomainModuleCard(module: module, onSelect: { onSelectModule(module) }, onSelectNode: onSelectNode)
            }
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            ForEach(modules) { module in
                moduleListRow(module)
                if module.id != modules.last?.id {
                    trackWorkspaceDivider
                }
            }
        }
        .trackWorkspaceSurface()
    }

    @ViewBuilder
    private func moduleListRow(_ module: Module) -> some View {
        let nodes = module.nodes.filter { !$0.isDeletedLocally }.roadmapSorted()
        let row = HStack(alignment: .top, spacing: 10) {
            #if os(macOS)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SymphoTheme.tertiaryText)
                .padding(.top, 2)
            #endif

            VStack(alignment: .leading, spacing: 6) {
                Button { onSelectModule(module) } label: {
                    Text(module.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                if !module.desc.isEmpty {
                    Text(module.desc)
                        .font(.system(size: 11))
                        .foregroundStyle(SymphoTheme.secondaryText)
                        .lineLimit(2)
                }

                if nodes.isEmpty {
                    Text("No nodes")
                        .font(.system(size: 10))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(nodes.prefix(4)) { node in
                            Button { onSelectNode(node) } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: nodeStatusIcon(node.status))
                                        .font(.system(size: 10))
                                        .foregroundStyle(roadmapNodeColor(node.status))
                                    Text(node.title)
                                        .font(.system(size: 11))
                                        .foregroundStyle(SymphoTheme.primaryText)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)

        Group {
            #if os(macOS)
            row
                .onDrag {
                    draggedModuleID = module.id
                    return NSItemProvider(object: module.id.uuidString as NSString)
                }
                .onDrop(
                    of: [.text],
                    delegate: RoadmapReorderDropDelegate(
                        destinationID: module.id,
                        orderedIDs: modules.map(\.id),
                        draggedID: draggedModuleID,
                        onReorder: applyModuleOrder
                    ) { draggedModuleID = nil }
                )
            #else
            row
            #endif
        }
        .symphoCardContextMenu(
            edit: { editModuleTarget = module },
            delete: { softDeleteModule(module) }
        )
    }

    private func softDeleteModule(_ module: Module) {
        module.isDeletedLocally = true
        module.isSynced = false
        module.updatedAt = Date()
        track.updatedAt = Date()
        track.isSynced = false
        try? modelContext.save()
    }

    private var trackWorkspaceDivider: some View {
        Rectangle()
            .fill(SymphoTheme.dividerColor)
            .frame(height: 1)
            .padding(.leading, 14)
    }

    private func applyModuleOrder(_ ids: [UUID]) {
        let byID = Dictionary(uniqueKeysWithValues: modules.map { ($0.id, $0) })
        for (index, id) in ids.enumerated() {
            byID[id]?.sortIndex = index
            byID[id]?.updatedAt = Date()
        }
        track.updatedAt = Date()
        track.isSynced = false
        try? modelContext.save()
    }

    private func nodeStatusIcon(_ status: NodeStatus) -> String {
        switch status {
        case .backlog: return "circle"
        case .active: return "play.circle.fill"
        case .mastered: return "checkmark.circle.fill"
        }
    }
}

extension View {
    func trackWorkspaceSurface() -> some View {
        background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SymphoTheme.elevatedCanvas.opacity(0.56))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        }
    }
}
