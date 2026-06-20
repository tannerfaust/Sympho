//
//  PlannerView.swift
//  Sympho
//

import SwiftUI
import SwiftData

struct PlannerView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\PlannerWeeklyBlock.weekday), SortDescriptor(\PlannerWeeklyBlock.sortIndex)])
    private var weeklyBlocks: [PlannerWeeklyBlock]

    @Query(
        filter: #Predicate<Domain> { !$0.isArchived && !$0.isDeletedLocally },
        sort: [SortDescriptor(\Domain.sortIndex), SortDescriptor(\Domain.title)]
    )
    private var domains: [Domain]

    @Query(filter: #Predicate<Project> { !$0.isDeletedLocally }, sort: \Project.title)
    private var projects: [Project]

    @Query(filter: #Predicate<ReadingListItem> { !$0.isDeletedLocally }, sort: \ReadingListItem.title)
    private var readingItems: [ReadingListItem]

    @Query(filter: #Predicate<Resource> { !$0.isDeletedLocally }, sort: \Resource.title)
    private var resources: [Resource]

    @State private var showsItemSheet = false
    @State private var editingBlock: PlannerWeeklyBlock?
    @State private var sheetWeekday = 1
    @State private var sheetDate: Date?

    private var todayKey: String { PlannerLogic.dayKey(for: Date()) }
    private var weekPlans: [PlannerDayPlan] {
        PlannerLogic.buildCurrentWeekPlans(
            weeklyBlocks: weeklyBlocks,
            domains: domains,
            projects: projects,
            readingItems: readingItems,
            resources: resources
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            HStack(alignment: .top, spacing: 8) {
                ForEach(weekPlans) { plan in
                    PlannerDayColumn(
                        plan: plan,
                        isToday: plan.dayKey == todayKey,
                        onEditEntry: { openBlock(id: $0) },
                        onAddEntry: {
                            editingBlock = nil
                            sheetWeekday = plan.weekday
                            sheetDate = plan.date
                            showsItemSheet = true
                        },
                        onDeleteEntry: deleteBlock(id:)
                    )
                }
            }
            .padding(.horizontal, SymphoTheme.outerPadding)
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SymphoTheme.primaryCanvas)
        .sheet(isPresented: $showsItemSheet) {
            PlannerStudyItemSheet(
                block: editingBlock,
                defaultWeekday: sheetWeekday,
                defaultDate: sheetDate,
                domains: domains,
                projects: projects,
                readingItems: readingItems,
                resources: resources
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Weekly plan")
                .editorialHeader()
            Text("Schedule domains, projects, books, and library items.")
                .metadataSans()
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    private func openBlock(id: UUID) {
        guard let block = weeklyBlocks.first(where: { $0.id == id }) else { return }
        editingBlock = block
        sheetWeekday = block.weekday
        sheetDate = PlannerLogic.daysInCurrentWeek().first(where: { PlannerLogic.isoWeekday(for: $0) == block.weekday })
        showsItemSheet = true
    }

    private func deleteBlock(id: UUID) {
        guard let block = weeklyBlocks.first(where: { $0.id == id }) else { return }
        modelContext.delete(block)
        try? modelContext.save()
    }
}

// MARK: - Day column

private struct PlannerDayColumn: View {
    let plan: PlannerDayPlan
    let isToday: Bool
    var onEditEntry: (UUID) -> Void
    var onAddEntry: () -> Void
    var onDeleteEntry: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(PlannerLogic.weekdayLabel(plan.weekday))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isToday ? SymphoTheme.primaryCanvas.opacity(0.8) : SymphoTheme.tertiaryText)
                Text(plan.date.formatted(.dateTime.day()))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isToday ? SymphoTheme.primaryCanvas : SymphoTheme.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isToday ? SymphoTheme.primaryText : Color.clear)
            }

            VStack(alignment: .leading, spacing: 5) {
                if plan.entries.isEmpty {
                    Text("—")
                        .font(.system(size: 11))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(plan.entries) { entry in
                        PlannerStudyEntryRow(entry: entry) {
                            onEditEntry(entry.id)
                        }
                        .contextMenu {
                            Button("Edit") { onEditEntry(entry.id) }
                            Button("Remove", role: .destructive) { onDeleteEntry(entry.id) }
                        }
                    }
                }
            }

            Button(action: onAddEntry) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .help("Add to \(PlannerLogic.weekdayLabel(plan.weekday))")
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SymphoTheme.elevatedCanvas.opacity(0.32))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(SymphoTheme.dividerColor.opacity(0.9), lineWidth: 1)
        }
    }
}

private struct PlannerStudyEntryRow: View {
    let entry: PlannerStudyEntry
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: entry.iconName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(SymphoTheme.secondaryText)

                    Text(entry.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Text(PlannerLogic.formatDuration(minutes: entry.durationMinutes))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(SymphoTheme.primaryCanvas.opacity(0.72))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sheet

struct PlannerStudyItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let block: PlannerWeeklyBlock?
    var defaultWeekday: Int = 1
    var defaultDate: Date?
    let domains: [Domain]
    let projects: [Project]
    let readingItems: [ReadingListItem]
    let resources: [Resource]

    @State private var targetKind: PlannerTargetKind = .domain
    @State private var selectedDomain: Domain?
    @State private var selectedProject: Project?
    @State private var selectedReadingItem: ReadingListItem?
    @State private var selectedResource: Resource?
    @State private var weekday = 1
    @State private var durationMinutes = 60

    private var isAdding: Bool { block == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(sheetTitle)
                    .font(.system(size: 20, weight: .semibold))

                if let sheetSubtitle {
                    Text(sheetSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(SymphoTheme.secondaryText)
                }
            }

            plannerSheetField("Type") {
                Picker("", selection: $targetKind) {
                    ForEach(PlannerTargetKind.allCases) { kind in
                        Label(kind.displayName, systemImage: kind.iconName).tag(kind)
                    }
                }
                .labelsHidden()
            }

            plannerSheetField(selectionFieldTitle) {
                switch targetKind {
                case .domain:
                    Picker("", selection: $selectedDomain) {
                        Text("Choose domain").tag(Optional<Domain>.none)
                        ForEach(domains) { domain in
                            Text(domain.title).tag(Optional(domain))
                        }
                    }
                    .labelsHidden()
                case .project:
                    Picker("", selection: $selectedProject) {
                        Text("Choose project").tag(Optional<Project>.none)
                        ForEach(projects) { project in
                            Text(project.title).tag(Optional(project))
                        }
                    }
                    .labelsHidden()
                case .reading:
                    Picker("", selection: $selectedReadingItem) {
                        Text("Choose book").tag(Optional<ReadingListItem>.none)
                        ForEach(readingItems) { item in
                            Text(readingItemLabel(item)).tag(Optional(item))
                        }
                    }
                    .labelsHidden()
                case .library:
                    Picker("", selection: $selectedResource) {
                        Text("Choose item").tag(Optional<Resource>.none)
                        ForEach(resources) { resource in
                            Text(resource.title).tag(Optional(resource))
                        }
                    }
                    .labelsHidden()
                }
            }

            if !isAdding {
                plannerSheetField("Day") {
                    Picker("", selection: $weekday) {
                        ForEach(1...7, id: \.self) { day in
                            Text(PlannerLogic.weekdayLabel(day)).tag(day)
                        }
                    }
                    .labelsHidden()
                }
            }

            PlannerDurationPicker(durationMinutes: $durationMinutes)

            HStack {
                if block != nil {
                    Button("Remove", role: .destructive) { deleteBlock() }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .padding(24)
        #if os(macOS)
        .frame(width: 420)
        #endif
        .onAppear(perform: load)
        .onChange(of: targetKind) { _, newKind in
            switch newKind {
            case .domain:
                selectedProject = nil
                selectedReadingItem = nil
                selectedResource = nil
                if selectedDomain == nil { selectedDomain = domains.first }
            case .project:
                selectedDomain = nil
                selectedReadingItem = nil
                selectedResource = nil
                if selectedProject == nil { selectedProject = projects.first }
            case .reading:
                selectedDomain = nil
                selectedProject = nil
                selectedResource = nil
                if selectedReadingItem == nil { selectedReadingItem = readingItems.first }
            case .library:
                selectedDomain = nil
                selectedProject = nil
                selectedReadingItem = nil
                if selectedResource == nil { selectedResource = resources.first }
            }
        }
    }

    private var sheetTitle: String {
        if isAdding {
            return "Add to \(PlannerLogic.weekdayLabel(defaultWeekday))"
        }
        return "Edit plan item"
    }

    private var sheetSubtitle: String? {
        if isAdding, let defaultDate {
            return defaultDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        }
        if !isAdding {
            return PlannerLogic.weekdayLabel(weekday)
        }
        return nil
    }

    private var selectionFieldTitle: String {
        switch targetKind {
        case .domain: return "Domain"
        case .project: return "Project"
        case .reading: return "Book"
        case .library: return "Library item"
        }
    }

    private func readingItemLabel(_ item: ReadingListItem) -> String {
        let author = item.author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !author.isEmpty else { return item.title }
        return "\(item.title) · \(author)"
    }

    private var canSave: Bool {
        switch targetKind {
        case .domain: return selectedDomain != nil
        case .project: return selectedProject != nil
        case .reading: return selectedReadingItem != nil
        case .library: return selectedResource != nil
        }
    }

    private func load() {
        weekday = block?.weekday ?? defaultWeekday
        durationMinutes = block?.durationMinutes ?? 60

        if let block {
            targetKind = block.targetKind
            if let id = block.linkedDomainID {
                selectedDomain = domains.first(where: { $0.id == id })
            }
            if let id = block.linkedProjectID {
                selectedProject = projects.first(where: { $0.id == id })
            }
            if let id = block.linkedReadingItemID {
                selectedReadingItem = readingItems.first(where: { $0.id == id })
            }
            if let id = block.linkedResourceID {
                selectedResource = resources.first(where: { $0.id == id })
            }
        } else {
            selectedDomain = domains.first
            selectedProject = projects.first
            selectedReadingItem = readingItems.first
            selectedResource = resources.first
        }
    }

    private func resolvedTitle() -> String {
        switch targetKind {
        case .domain: return selectedDomain?.title ?? ""
        case .project: return selectedProject?.title ?? ""
        case .reading: return selectedReadingItem?.title ?? ""
        case .library: return selectedResource?.title ?? ""
        }
    }

    private func save() {
        guard canSave else { return }

        let resolvedWeekday = isAdding ? defaultWeekday : weekday

        if let block {
            block.targetKind = targetKind
            block.linkedDomainID = targetKind == .domain ? selectedDomain?.id : nil
            block.linkedProjectID = targetKind == .project ? selectedProject?.id : nil
            block.linkedReadingItemID = targetKind == .reading ? selectedReadingItem?.id : nil
            block.linkedResourceID = targetKind == .library ? selectedResource?.id : nil
            block.title = resolvedTitle()
            block.weekday = resolvedWeekday
            block.durationMinutes = durationMinutes
            block.startMinute = durationMinutes
            block.endMinute = 0
            block.notes = ""
            block.updatedAt = Date()
        } else {
            modelContext.insert(
                PlannerWeeklyBlock(
                    weekday: resolvedWeekday,
                    targetKind: targetKind,
                    domain: targetKind == .domain ? selectedDomain : nil,
                    project: targetKind == .project ? selectedProject : nil,
                    readingItem: targetKind == .reading ? selectedReadingItem : nil,
                    resource: targetKind == .library ? selectedResource : nil,
                    durationMinutes: durationMinutes
                )
            )
        }

        try? modelContext.save()
        dismiss()
    }

    private func deleteBlock() {
        if let block { modelContext.delete(block) }
        try? modelContext.save()
        dismiss()
    }
}

private struct PlannerDurationPicker: View {
    @Binding var durationMinutes: Int

    private let presets = [15, 30, 45, 60, 90, 120, 180]
    private let minMinutes = 15
    private let maxMinutes = 480
    private let step = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Duration")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SymphoTheme.secondaryText)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6),
                ],
                spacing: 6
            ) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        durationMinutes = preset
                    } label: {
                        Text(PlannerLogic.formatDuration(minutes: preset))
                            .font(.system(size: 11, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(durationMinutes == preset ? SymphoTheme.primaryText : SymphoTheme.primaryCanvas.opacity(0.65))
                            }
                            .foregroundStyle(durationMinutes == preset ? SymphoTheme.primaryCanvas : SymphoTheme.primaryText)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 16) {
                Button { adjustDuration(by: -step) } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(durationMinutes <= minMinutes)

                VStack(spacing: 2) {
                    Text(PlannerLogic.formatDuration(minutes: durationMinutes))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .monospacedDigit()

                    Text("15 min steps")
                        .font(.system(size: 10))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                }
                .frame(minWidth: 96)

                Button { adjustDuration(by: step) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(durationMinutes >= maxMinutes)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SymphoTheme.elevatedCanvas.opacity(0.72))
        }
    }

    private func adjustDuration(by delta: Int) {
        durationMinutes = min(maxMinutes, max(minMinutes, durationMinutes + delta))
    }
}

@ViewBuilder
private func plannerSheetField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(SymphoTheme.secondaryText)
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 11)
    .padding(.vertical, 10)
    .background {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(SymphoTheme.elevatedCanvas.opacity(0.72))
    }
}
