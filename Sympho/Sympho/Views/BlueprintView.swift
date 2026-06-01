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

// MARK: - Domain roadmap

struct DomainRoadmapView: View {
    @Environment(\.modelContext) private var modelContext

    let domain: Domain
    var onSelectTrack: (Track) -> Void
    var onSelectModule: (Module) -> Void

    @State private var expandedTrackIDs: Set<UUID> = []
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
                Text("Add a track, then modules inside it.")
                    .font(.system(size: 12))
                    .foregroundStyle(SymphoTheme.secondaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(sortedTracks) { track in
                        trackSection(track)
                        if track.id != sortedTracks.last?.id {
                            roadmapDivider
                        }
                    }
                }

                if !sortedStandaloneModules.isEmpty || addingStandaloneModule {
                    standaloneSection
                }
            }

            if addingTrack {
                inlineComposer(placeholder: "Track name", onSave: saveNewTrack)
            } else {
                addAction("Add track", action: beginAddingTrack)
            }
        }
        .onAppear(perform: seedExpansionIfNeeded)
        .sheet(item: $editTarget) { target in
            SymphoItemEditSheet(subject: target.subject) {
                editTarget = nil
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Roadmap")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SymphoTheme.primaryText)
            Spacer()
            Button(action: beginAddingTrack) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(SymphoTheme.secondaryText)
        }
    }

    @ViewBuilder
    private func trackSection(_ track: Track) -> some View {
        let isExpanded = expandedTrackIDs.contains(track.id)
        let modules = track.modules.filter { !$0.isDeletedLocally }.roadmapSorted()

        VStack(alignment: .leading, spacing: 0) {
            trackRow(track, isExpanded: isExpanded)
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

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(modules) { module in
                        moduleRow(module, leadingInset: 28)
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
                        inlineComposer(placeholder: "Module name", onSave: { saveNewModule(in: track) })
                            .padding(.leading, 28)
                    } else {
                        addAction("Add module", inset: 28) {
                            beginAddingModule(in: track)
                        }
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 6)
            }
        }
    }

    private var standaloneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Without track")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SymphoTheme.tertiaryText)
                .padding(.top, 16)

            VStack(spacing: 0) {
                ForEach(sortedStandaloneModules) { module in
                    moduleRow(module, leadingInset: 0)
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
            }

            if addingStandaloneModule {
                inlineComposer(placeholder: "Module name", onSave: saveNewStandaloneModule)
            } else {
                addAction("Add module", action: beginAddingStandaloneModule)
            }
        }
    }

    private func trackRow(_ track: Track, isExpanded: Bool) -> some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.snappy(duration: 0.15)) { toggleTrack(track.id) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(SymphoTheme.tertiaryText)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 20, height: 32)
            }
            .buttonStyle(.plain)

            Button { onSelectTrack(track) } label: {
                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 36)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit", systemImage: "pencil") { editTarget = .track(track) }
            Button("Delete", role: .destructive) { softDeleteTrack(track) }
        }
    }

    private func moduleRow(_ module: Module, leadingInset: CGFloat) -> some View {
        Button { onSelectModule(module) } label: {
            Text(module.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SymphoTheme.primaryText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, leadingInset)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit", systemImage: "pencil") { editTarget = .module(module) }
            Button("Delete", role: .destructive) { softDeleteModule(module) }
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

    private var roadmapDivider: some View {
        Rectangle()
            .fill(SymphoTheme.dividerColor.opacity(0.7))
            .frame(height: 1)
            .padding(.leading, 26)
    }

    private func addAction(_ title: String, inset: CGFloat = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SymphoTheme.tertiaryText)
                .padding(.leading, inset)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func inlineComposer(placeholder: String, onSave: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $draftTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit(onSave)
            Button("Add", action: onSave)
                .font(.system(size: 11, weight: .semibold))
                .buttonStyle(.plain)
            Button("Cancel", action: cancelComposer)
                .font(.system(size: 11))
                .foregroundStyle(SymphoTheme.tertiaryText)
                .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }

    // MARK: - State

    private func seedExpansionIfNeeded() {
        if expandedTrackIDs.isEmpty {
            expandedTrackIDs = Set(sortedTracks.map(\.id))
        }
        normalizeSortIndicesIfNeeded()
    }

    private func toggleTrack(_ id: UUID) {
        withAnimation(.snappy(duration: 0.15)) {
            if expandedTrackIDs.contains(id) {
                expandedTrackIDs.remove(id)
            } else {
                expandedTrackIDs.insert(id)
            }
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
                Text("Modules")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button {
                    cancelComposer()
                    addingModule = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(SymphoTheme.secondaryText)
            }

            if modules.isEmpty && !addingModule {
                Text("Add modules for this track.")
                    .font(.system(size: 12))
                    .foregroundStyle(SymphoTheme.secondaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(modules) { module in
                        Button { onSelectModule(module) } label: {
                            Text(module.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(SymphoTheme.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 9)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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

                        if module.id != modules.last?.id {
                            Rectangle()
                                .fill(SymphoTheme.dividerColor.opacity(0.65))
                                .frame(height: 1)
                        }
                    }
                }
            }

            if addingModule {
                HStack(spacing: 8) {
                    TextField("Module name", text: $draftTitle)
                        .textFieldStyle(.plain)
                        .onSubmit(saveNewModule)
                    Button("Add", action: saveNewModule)
                        .font(.system(size: 11, weight: .semibold))
                        .buttonStyle(.plain)
                    Button("Cancel", action: cancelComposer)
                        .font(.system(size: 11))
                        .buttonStyle(.plain)
                }
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
