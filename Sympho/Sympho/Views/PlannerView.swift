//
//  PlannerView.swift
//  Sympho
//

import SwiftUI
import SwiftData

struct PlannerView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\PlannerWeeklyBlock.weekday), SortDescriptor(\PlannerWeeklyBlock.startMinute)])
    private var weeklyBlocks: [PlannerWeeklyBlock]

    @Query(sort: \PlannerDayNote.dayKey) private var dayNotes: [PlannerDayNote]

    @State private var weekAnchor = Date()
    @State private var todayNoteText = ""
    @State private var showsBlockSheet = false
    @State private var editingBlock: PlannerWeeklyBlock?
    @State private var newBlockWeekday = 1

    private var today: Date { Date() }
    private var todayKey: String { PlannerLogic.dayKey(for: today) }
    private var todayAgenda: PlannerDayAgenda {
        PlannerLogic.buildDayAgenda(date: today, weeklyBlocks: weeklyBlocks)
    }
    private var weekAgendas: [PlannerDayAgenda] {
        PlannerLogic.buildWeekAgendas(containing: weekAnchor, weeklyBlocks: weeklyBlocks)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                todaySection
                weekToolbar
                weekSection
            }
            .padding(.bottom, SymphoTheme.outerPadding)
        }
        .background(SymphoTheme.primaryCanvas)
        .onAppear { loadTodayNote() }
        .onChange(of: todayNoteText) { _, _ in saveTodayNoteDebounced() }
        .sheet(isPresented: $showsBlockSheet) {
            PlannerWeeklyBlockSheet(block: editingBlock, defaultWeekday: newBlockWeekday)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Planner")
                .editorialHeader()
            Text("Weekly rhythm for study and training.")
                .metadataSans()
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
        .padding(.top, 16)
        .padding(.bottom, 22)
    }

    // MARK: - Today

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .editorialTitle()
                    Text(PlannerLogic.casualTodayPrompt(for: today))
                        .captionSans()
                }
                Spacer()
                Text(today.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SymphoTheme.secondaryText)
            }

            TextField("A loose note for today…", text: $todayNoteText, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .font(.system(size: 14))

            if todayAgenda.slots.isEmpty {
                Text("No rhythm blocks today — add slots in the week view below.")
                    .captionSans()
            } else {
                VStack(spacing: 6) {
                    ForEach(todayAgenda.slots) { slot in
                        PlannerSlotRow(slot: slot) {
                            openBlock(id: slot.id)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
        .padding(.bottom, 28)
    }

    // MARK: - Week

    private var weekToolbar: some View {
        HStack(alignment: .center) {
            Text("Week rhythm")
                .editorialSubtitle()
            Spacer()
            SymphoGlassAddButton(help: "Add weekly slot", size: 30, iconSize: 14) {
                editingBlock = nil
                newBlockWeekday = PlannerLogic.isoWeekday(for: today)
                showsBlockSheet = true
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
        .padding(.bottom, 12)
    }

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            weekNavigator

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 112, maximum: .infinity), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(weekAgendas) { agenda in
                    PlannerDayColumn(
                        agenda: agenda,
                        isToday: agenda.dayKey == todayKey,
                        onEditBlock: { openBlock(id: $0) },
                        onAddBlock: {
                            editingBlock = nil
                            newBlockWeekday = agenda.weekday
                            showsBlockSheet = true
                        }
                    )
                }
            }
            .padding(.horizontal, SymphoTheme.outerPadding)
        }
    }

    private var weekNavigator: some View {
        let interval = PlannerLogic.weekInterval(containing: weekAnchor)
        let endLabel = Calendar.current.date(byAdding: .day, value: -1, to: interval.end)

        return HStack {
            Button { shiftWeek(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)

            Text("\(interval.start.formatted(.dateTime.month(.abbreviated).day())) – \(endLabel?.formatted(.dateTime.month(.abbreviated).day()) ?? "")")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SymphoTheme.secondaryText)

            Button { shiftWeek(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)

            Spacer()

            if !Calendar.current.isDate(weekAnchor, equalTo: today, toGranularity: .weekOfYear) {
                Button("This week") {
                    withAnimation(.snappy(duration: 0.2)) { weekAnchor = today }
                }
                .font(.system(size: 11, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(SymphoTheme.secondaryText)
            }
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
    }

    // MARK: - Helpers

    private func loadTodayNote() {
        todayNoteText = dayNotes.first(where: { $0.dayKey == todayKey })?.text ?? ""
    }

    private func saveTodayNoteDebounced() {
        if let existing = dayNotes.first(where: { $0.dayKey == todayKey }) {
            if existing.text == todayNoteText {
                return
            }
            if todayNoteText.isEmpty {
                modelContext.delete(existing)
            } else {
                existing.text = todayNoteText
                existing.updatedAt = Date()
            }
        } else if !todayNoteText.isEmpty {
            modelContext.insert(PlannerDayNote(dayKey: todayKey, text: todayNoteText))
        }
        try? modelContext.save()
    }

    private func shiftWeek(by weeks: Int) {
        if let d = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: weekAnchor) {
            weekAnchor = d
        }
    }

    private func openBlock(id: UUID) {
        guard let block = weeklyBlocks.first(where: { $0.id == id }) else { return }
        editingBlock = block
        newBlockWeekday = block.weekday
        showsBlockSheet = true
    }
}

// MARK: - Subviews

private struct PlannerDayColumn: View {
    let agenda: PlannerDayAgenda
    let isToday: Bool
    var onEditBlock: (UUID) -> Void
    var onAddBlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(PlannerLogic.weekdayLabel(agenda.weekday))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isToday ? SymphoTheme.primaryCanvas.opacity(0.8) : SymphoTheme.tertiaryText)
                Text(agenda.date.formatted(.dateTime.day()))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isToday ? SymphoTheme.primaryCanvas : SymphoTheme.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isToday ? SymphoTheme.primaryText : Color.clear)
            }

            if agenda.slots.isEmpty {
                Text("—")
                    .font(.system(size: 11))
                    .foregroundStyle(SymphoTheme.tertiaryText)
                    .frame(maxWidth: .infinity, minHeight: 48)
            } else {
                VStack(spacing: 6) {
                    ForEach(agenda.slots) { slot in
                        PlannerWeekSlotCard(slot: slot) {
                            onEditBlock(slot.id)
                        }
                    }
                }
            }

            Button(action: onAddBlock) {
                Text("Add")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(10)
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

private struct PlannerWeekSlotCard: View {
    let slot: PlannerTimedSlot
    var onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: slot.kind.iconName)
                        .font(.system(size: 8, weight: .semibold))
                    Text(PlannerLogic.formatTime(minutes: slot.startMinute))
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(plannerKindColor(slot.kind))

                Text(slot.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(plannerKindColor(slot.kind).opacity(0.1))
            }
        }
        .buttonStyle(.plain)
    }
}

struct PlannerSlotRow: View {
    let slot: PlannerTimedSlot
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(plannerKindColor(slot.kind))
                    .frame(width: 3, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SymphoTheme.primaryText)
                    Text("\(PlannerLogic.formatTime(minutes: slot.startMinute)) – \(PlannerLogic.formatTime(minutes: slot.endMinute))")
                        .font(.system(size: 11))
                        .foregroundStyle(SymphoTheme.secondaryText)
                }

                Spacer(minLength: 0)

                Image(systemName: slot.kind.iconName)
                    .font(.system(size: 12))
                    .foregroundStyle(plannerKindColor(slot.kind))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }
}

// MARK: - Sheet

struct PlannerWeeklyBlockSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let block: PlannerWeeklyBlock?
    var defaultWeekday: Int = 1

    @State private var title = ""
    @State private var notes = ""
    @State private var kind: PlannerBlockKind = .study
    @State private var weekday = 1
    @State private var startHour = 9
    @State private var startMin = 0
    @State private var endHour = 10
    @State private var endMin = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(block == nil ? "Weekly slot" : "Edit slot")
                .font(.system(size: 20, weight: .semibold))

            plannerSheetField("Title") { TextField("e.g. Morning study", text: $title).textFieldStyle(.plain) }
            plannerSheetField("Type") {
                Picker("", selection: $kind) {
                    ForEach(PlannerBlockKind.allCases) { k in
                        Label(k.displayName, systemImage: k.iconName).tag(k)
                    }
                }
                .labelsHidden()
            }
            plannerSheetField("Day") {
                Picker("", selection: $weekday) {
                    ForEach(1...7, id: \.self) { d in
                        Text(PlannerLogic.weekdayLabel(d)).tag(d)
                    }
                }
                .labelsHidden()
            }
            plannerSheetField("Time") {
                HStack {
                    timeStepper(hour: $startHour, minute: $startMin)
                    Text("to").foregroundStyle(SymphoTheme.tertiaryText)
                    timeStepper(hour: $endHour, minute: $endMin)
                }
            }
            plannerSheetField("Notes") {
                TextField("Optional", text: $notes, axis: .vertical).lineLimit(2...4).textFieldStyle(.plain)
            }

            HStack {
                if block != nil {
                    Button("Delete", role: .destructive) { deleteBlock() }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear(perform: load)
    }

    private func load() {
        guard let block else {
            weekday = defaultWeekday
            return
        }
        title = block.title
        notes = block.notes
        kind = block.kind
        weekday = block.weekday
        startHour = block.startMinute / 60
        startMin = block.startMinute % 60
        endHour = block.endMinute / 60
        endMin = block.endMinute % 60
    }

    private func save() {
        let start = startHour * 60 + startMin
        let end = max(start + 15, endHour * 60 + endMin)
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let block {
            block.title = trimmed
            block.notes = notes
            block.kind = kind
            block.weekday = weekday
            block.startMinute = start
            block.endMinute = end
            block.updatedAt = Date()
        } else {
            modelContext.insert(
                PlannerWeeklyBlock(
                    title: trimmed,
                    notes: notes,
                    kind: kind,
                    weekday: weekday,
                    startMinute: start,
                    endMinute: end
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

    @ViewBuilder
    private func timeStepper(hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: 4) {
            Stepper("\(hour.wrappedValue)", value: hour, in: 0...23).labelsHidden()
            Text(":")
            Stepper(String(format: "%02d", minute.wrappedValue), value: minute, in: 0...59, step: 15).labelsHidden()
        }
        .font(.system(size: 12, weight: .medium, design: .monospaced))
    }
}

@ViewBuilder
private func plannerSheetField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    HStack(spacing: 10) {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .frame(width: 56, alignment: .leading)
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
