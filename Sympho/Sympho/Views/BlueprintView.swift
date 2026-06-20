//
//  BlueprintView.swift
//  Sympho
//
//  Domain roadmap — tracks with expandable modules, drag reorder, no canvas.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum RoadmapEditTarget: Identifiable {
    case track(Track)
    case module(Module)

    var id: UUID {
        switch self {
        case .track(let track): return track.id
        case .module(let module): return module.id
        }
    }

    var subject: SymphoEditSubject {
        switch self {
        case .track(let track): return .track(track)
        case .module(let module): return .module(module)
        }
    }
}

// MARK: - Shared roadmap blocks

private struct RoadmapModuleBlock: View {
    let module: Module
    var onSelect: () -> Void

    private var nodeCount: Int {
        module.nodes.filter { !$0.isDeletedLocally }.count
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .frame(width: 34, height: 34)
                    .background(SymphoTheme.elevatedCanvas.opacity(0.9), in: .rect(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 3) {
                    Text("MODULE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                        .tracking(0.5)

                    Text(module.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Text(nodeCount == 1 ? "1 node" : "\(nodeCount) nodes")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SymphoTheme.secondaryText)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SymphoTheme.primaryCanvas.opacity(0.72), in: .rect(cornerRadius: 11))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(SymphoTheme.dividerColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct RoadmapInlineComposer: View {
    let placeholder: String
    @Binding var draftTitle: String
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $draftTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(SymphoTheme.primaryCanvas.opacity(0.85), in: .rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                }
                .onSubmit(onSave)

            Button("Add", action: onSave)
                .buttonStyle(SymphoSecondaryButtonStyle())

            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(SymphoTheme.tertiaryText)
        }
        .padding(11)
        .background(SymphoTheme.elevatedCanvas.opacity(0.45), in: .rect(cornerRadius: 11))
    }
}

private struct RoadmapAddButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(SymphoTheme.secondaryText)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Domain roadmap

struct DomainRoadmapView: View {
    @Environment(\.modelContext) private var modelContext

    let domain: Domain
    var onSelectTrack: (Track) -> Void
    var onSelectModule: (Module) -> Void

    @State private var expandedTrackIDs: Set<UUID> = []
    @State private var didRestoreExpansion = false
    @State private var addingTrack = false
    @State private var addingModuleTrackID: UUID?
    @State private var addingStandaloneModule = false
    @State private var draftTitle = ""
    @State private var draggedTrackID: UUID?
    @State private var draggedModuleID: UUID?
    @State private var editTarget: RoadmapEditTarget?

    private var sortedTracks: [Track] {
        domain.tracks.filter { !$0.isDeletedLocally }.roadmapSorted()
    }

    private var sortedStandaloneModules: [Module] {
        domain.modules.filter { !$0.isDeletedLocally && $0.track == nil }.roadmapSorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if sortedTracks.isEmpty && sortedStandaloneModules.isEmpty && !addingTrack && !addingStandaloneModule {
                roadmapEmptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(sortedTracks) { track in
                        trackCard(track)
                            #if os(macOS)
                            .onDrag {
                                draggedTrackID = track.id
                                return NSItemProvider(object: track.id.uuidString as NSString)
                            }
                            .onDrop(
                                of: [.text],
                                delegate: RoadmapReorderDropDelegate(
                                    destinationID: track.id,
                                    orderedIDs: sortedTracks.map(\.id),
                                    draggedID: draggedTrackID,
                                    onReorder: applyTrackOrder,
                                    onEnd: { draggedTrackID = nil }
                                )
                            )
                            #endif
                    }
                }

                if !sortedStandaloneModules.isEmpty || addingStandaloneModule {
                    standaloneCard
                }
            }

            if addingTrack {
                RoadmapInlineComposer(
                    placeholder: "Track name",
                    draftTitle: $draftTitle,
                    onSave: saveNewTrack,
                    onCancel: cancelComposer
                )
            } else {
                RoadmapAddButton(title: "Add track", action: beginAddingTrack)
            }
        }
        .onAppear {
            restoreExpansionStateIfNeeded()
            normalizeSortIndicesIfNeeded()
        }
        .sheet(item: $editTarget) { target in
            SymphoItemEditSheet(subject: target.subject) {
                editTarget = nil
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Roadmap")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)

                Text("Tracks and modules in learning order")
                    .font(.system(size: 11))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }

            Spacer()

            Button(action: beginAddingTrack) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help("Add track")
        }
    }

    private var roadmapEmptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No roadmap yet")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SymphoTheme.primaryText)

            Text("Add a track, then place modules inside it.")
                .font(.system(size: 12))
                .foregroundStyle(SymphoTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(SymphoTheme.elevatedCanvas.opacity(0.5), in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SymphoTheme.dividerColor, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        }
    }

    @ViewBuilder
    private func trackCard(_ track: Track) -> some View {
        let isExpanded = expandedTrackIDs.contains(track.id)
        let modules = track.modules.filter { !$0.isDeletedLocally }.roadmapSorted()

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    toggleTrack(track.id)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SymphoTheme.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                        .glassEffect(.regular, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse track" : "Expand track")

                Button(action: { onSelectTrack(track) }) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(SymphoTheme.primaryText)
                            .frame(width: 40, height: 40)
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("TRACK")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(SymphoTheme.tertiaryText)
                                .tracking(0.5)

                            Text(track.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(SymphoTheme.primaryText)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            HStack(spacing: 12) {
                                Label("\(modules.count) modules", systemImage: "square.stack.3d.up")
                                Label("\(track.allNodes.count) nodes", systemImage: "circle.hexagonpath")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(SymphoTheme.secondaryText)
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .contextMenu {
                Button("Edit", systemImage: "pencil") { editTarget = .track(track) }
                Button("Delete", role: .destructive) { softDeleteTrack(track) }
            }

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(modules) { module in
                        RoadmapModuleBlock(module: module) {
                            onSelectModule(module)
                        }
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") { editTarget = .module(module) }
                            Button("Delete", role: .destructive) { softDeleteModule(module) }
                        }
                        #if os(macOS)
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
                                onReorder: { applyModuleOrder($0, track: track) },
                                onEnd: { draggedModuleID = nil }
                            )
                        )
                        #endif
                    }

                    if addingModuleTrackID == track.id {
                        RoadmapInlineComposer(
                            placeholder: "Module name",
                            draftTitle: $draftTitle,
                            onSave: { saveNewModule(in: track) },
                            onCancel: cancelComposer
                        )
                    } else {
                        RoadmapAddButton(title: "Add module", action: { beginAddingModule(in: track) })
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(SymphoTheme.elevatedCanvas.opacity(0.55), in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        }
    }

    private var standaloneCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Standalone modules")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)

                Text("Modules not assigned to a track")
                    .font(.system(size: 11))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            VStack(spacing: 8) {
                ForEach(sortedStandaloneModules) { module in
                    RoadmapModuleBlock(module: module) {
                        onSelectModule(module)
                    }
                    .contextMenu {
                        Button("Edit", systemImage: "pencil") { editTarget = .module(module) }
                        Button("Delete", role: .destructive) { softDeleteModule(module) }
                    }
                    #if os(macOS)
                    .onDrag {
                        draggedModuleID = module.id
                        return NSItemProvider(object: module.id.uuidString as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: RoadmapReorderDropDelegate(
                            destinationID: module.id,
                            orderedIDs: sortedStandaloneModules.map(\.id),
                            draggedID: draggedModuleID,
                            onReorder: { applyModuleOrder($0, track: nil) },
                            onEnd: { draggedModuleID = nil }
                        )
                    )
                    #endif
                }

                if addingStandaloneModule {
                    RoadmapInlineComposer(
                        placeholder: "Module name",
                        draftTitle: $draftTitle,
                        onSave: saveNewStandaloneModule,
                        onCancel: cancelComposer
                    )
                } else {
                    RoadmapAddButton(title: "Add module", action: beginAddingStandaloneModule)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(SymphoTheme.elevatedCanvas.opacity(0.55), in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        }
    }

    private func softDeleteTrack(_ track: Track) {
        track.isDeletedLocally = true
        track.isSynced = false
        track.updatedAt = Date()
        touchDomain()
        try? modelContext.save()
    }

    private func softDeleteModule(_ module: Module) {
        module.isDeletedLocally = true
        module.isSynced = false
        module.updatedAt = Date()
        touchDomain()
        try? modelContext.save()
    }

    // MARK: - State

    private var expansionStorageKey: String {
        "roadmap.expandedTrackIDs.\(domain.id.uuidString)"
    }

    private var expansionInitializedKey: String {
        "roadmap.expansionInitialized.\(domain.id.uuidString)"
    }

    private func restoreExpansionStateIfNeeded() {
        guard !didRestoreExpansion else { return }
        didRestoreExpansion = true

        if UserDefaults.standard.bool(forKey: expansionInitializedKey),
           let stored = UserDefaults.standard.array(forKey: expansionStorageKey) as? [String] {
            expandedTrackIDs = Set(stored.compactMap(UUID.init(uuidString:)))
            return
        }

        expandedTrackIDs = Set(sortedTracks.map(\.id))
        persistExpansionState()
        UserDefaults.standard.set(true, forKey: expansionInitializedKey)
    }

    private func persistExpansionState() {
        UserDefaults.standard.set(expandedTrackIDs.map(\.uuidString), forKey: expansionStorageKey)
        UserDefaults.standard.set(true, forKey: expansionInitializedKey)
    }

    private func toggleTrack(_ id: UUID) {
        withAnimation(.snappy(duration: 0.15)) {
            if expandedTrackIDs.contains(id) {
                expandedTrackIDs.remove(id)
            } else {
                expandedTrackIDs.insert(id)
            }
            persistExpansionState()
        }
    }

    private func beginAddingTrack() {
        cancelComposer()
        addingTrack = true
    }

    private func beginAddingModule(in track: Track) {
        cancelComposer()
        addingModuleTrackID = track.id
        expandedTrackIDs.insert(track.id)
        persistExpansionState()
    }

    private func beginAddingStandaloneModule() {
        cancelComposer()
        addingStandaloneModule = true
    }

    private func cancelComposer() {
        draftTitle = ""
        addingTrack = false
        addingModuleTrackID = nil
        addingStandaloneModule = false
    }

    private func saveNewTrack() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let nextIndex = sortedTracks.map(\.sortIndex).max().map { $0 + 1 } ?? 0
        let track = Track(title: title, desc: "", sortIndex: nextIndex, domain: domain)
        modelContext.insert(track)
        domain.tracks.append(track)
        touchDomain()
        try? modelContext.save()
        expandedTrackIDs.insert(track.id)
        persistExpansionState()
        cancelComposer()
    }

    private func saveNewModule(in track: Track) {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let siblings = track.modules.filter { !$0.isDeletedLocally }
        let nextIndex = siblings.map(\.sortIndex).max().map { $0 + 1 } ?? 0
        let module = Module(title: title, desc: "", sortIndex: nextIndex, track: track, domain: domain)
        modelContext.insert(module)
        track.modules.append(module)
        touchDomain()
        try? modelContext.save()
        cancelComposer()
    }

    private func saveNewStandaloneModule() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let nextIndex = sortedStandaloneModules.map(\.sortIndex).max().map { $0 + 1 } ?? 0
        let module = Module(title: title, desc: "", sortIndex: nextIndex, domain: domain)
        modelContext.insert(module)
        domain.modules.append(module)
        touchDomain()
        try? modelContext.save()
        cancelComposer()
    }

    private func applyTrackOrder(_ ids: [UUID]) {
        let byID = Dictionary(uniqueKeysWithValues: sortedTracks.map { ($0.id, $0) })
        for (index, id) in ids.enumerated() {
            byID[id]?.sortIndex = index
            byID[id]?.updatedAt = Date()
        }
        touchDomain()
        try? modelContext.save()
    }

    private func applyModuleOrder(_ ids: [UUID], track: Track?) {
        let modules: [Module]
        if let track {
            modules = track.modules.filter { !$0.isDeletedLocally }.roadmapSorted()
        } else {
            modules = sortedStandaloneModules
        }
        let byID = Dictionary(uniqueKeysWithValues: modules.map { ($0.id, $0) })
        for (index, id) in ids.enumerated() {
            byID[id]?.sortIndex = index
            byID[id]?.updatedAt = Date()
        }
        touchDomain()
        try? modelContext.save()
    }

    private func normalizeSortIndicesIfNeeded() {
        assignSortIndicesIfUniform(sortedTracks)
        for track in sortedTracks {
            assignSortIndicesIfUniform(track.modules.filter { !$0.isDeletedLocally }.roadmapSorted())
        }
        assignSortIndicesIfUniform(sortedStandaloneModules)
    }

    private func assignSortIndicesIfUniform(_ tracks: [Track]) {
        guard tracks.count > 1, Set(tracks.map(\.sortIndex)).count <= 1 else { return }
        for (index, track) in tracks.enumerated() { track.sortIndex = index }
    }

    private func assignSortIndicesIfUniform(_ modules: [Module]) {
        guard modules.count > 1, Set(modules.map(\.sortIndex)).count <= 1 else { return }
        for (index, module) in modules.enumerated() { module.sortIndex = index }
    }

    private func touchDomain() {
        domain.updatedAt = Date()
        domain.isSynced = false
    }
}

// MARK: - Track roadmap (modules only)

struct TrackRoadmapView: View {
    @Environment(\.modelContext) private var modelContext

    let track: Track
    var onSelectModule: (Module) -> Void

    @State private var addingModule = false
    @State private var draftTitle = ""
    @State private var draggedModuleID: UUID?
    @State private var editTarget: RoadmapEditTarget?

    private var modules: [Module] {
        track.modules.filter { !$0.isDeletedLocally }.roadmapSorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Modules")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Ordered steps inside this track")
                        .font(.system(size: 11))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                }

                Spacer()

                Button {
                    cancelComposer()
                    addingModule = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }

            if modules.isEmpty && !addingModule {
                Text("Add modules for this track.")
                    .font(.system(size: 12))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SymphoTheme.elevatedCanvas.opacity(0.5), in: .rect(cornerRadius: 14))
            } else {
                VStack(spacing: 8) {
                    ForEach(modules) { module in
                        RoadmapModuleBlock(module: module) {
                            onSelectModule(module)
                        }
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") { editTarget = .module(module) }
                            Button("Delete", role: .destructive) { softDeleteModule(module) }
                        }
                        #if os(macOS)
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
                                onReorder: applyModuleOrder,
                                onEnd: { draggedModuleID = nil }
                            )
                        )
                        #endif
                    }
                }
            }

            if addingModule {
                RoadmapInlineComposer(
                    placeholder: "Module name",
                    draftTitle: $draftTitle,
                    onSave: saveNewModule,
                    onCancel: cancelComposer
                )
            }
        }
        .sheet(item: $editTarget) { target in
            SymphoItemEditSheet(subject: target.subject) { editTarget = nil }
        }
    }

    private func saveNewModule() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let nextIndex = modules.map(\.sortIndex).max().map { $0 + 1 } ?? 0
        let module = Module(title: title, desc: "", sortIndex: nextIndex, track: track, domain: track.domain)
        modelContext.insert(module)
        track.modules.append(module)
        track.updatedAt = Date()
        track.isSynced = false
        try? modelContext.save()
        cancelComposer()
    }

    private func cancelComposer() {
        draftTitle = ""
        addingModule = false
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

    private func softDeleteModule(_ module: Module) {
        module.isDeletedLocally = true
        module.isSynced = false
        module.updatedAt = Date()
        track.updatedAt = Date()
        track.isSynced = false
        try? modelContext.save()
    }
}

// MARK: - Reorder

#if os(macOS)
struct RoadmapReorderDropDelegate: DropDelegate {
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

// MARK: - Sorting

extension Array where Element == Track {
    func roadmapSorted() -> [Track] {
        sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            return lhs.createdAt < rhs.createdAt
        }
    }
}

extension Array where Element == Module {
    func roadmapSorted() -> [Module] {
        sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            return lhs.createdAt < rhs.createdAt
        }
    }
}

extension Array where Element == Node {
    func roadmapSorted() -> [Node] {
        sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            return lhs.createdAt < rhs.createdAt
        }
    }
}

func roadmapNodeColor(_ status: NodeStatus) -> Color {
    switch status {
    case .backlog: return SymphoTheme.secondaryText
    case .active: return SymphoTheme.colorActive
    case .mastered: return SymphoTheme.colorMastered
    }
}
