//
//  PlannerLogic.swift
//  Sympho
//

import Foundation
import SwiftUI

struct PlannerTimedSlot: Identifiable, Sendable {
    let id: UUID
    let title: String
    let notes: String
    let kind: PlannerBlockKind
    let startMinute: Int
    let endMinute: Int
}

struct PlannerDayAgenda: Identifiable, Sendable {
    var id: String { dayKey }
    let date: Date
    let dayKey: String
    let weekday: Int
    let slots: [PlannerTimedSlot]
}

enum PlannerLogic {
    static let calendar = Calendar.current

    static func dayKey(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func isoWeekday(for date: Date) -> Int {
        let w = calendar.component(.weekday, from: date)
        return w == 1 ? 7 : w - 1
    }

    static func weekInterval(containing date: Date) -> (start: Date, end: Date) {
        var cal = calendar
        cal.firstWeekday = 2
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 7, to: start) ?? start
        return (start, end)
    }

    static func daysInWeek(containing date: Date) -> [Date] {
        let start = weekInterval(containing: date).start
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func formatTime(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        var comps = DateComponents()
        comps.hour = h
        comps.minute = m
        let d = calendar.date(from: comps) ?? Date()
        return d.formatted(date: .omitted, time: .shortened)
    }

    static func buildDayAgenda(date: Date, weeklyBlocks: [PlannerWeeklyBlock]) -> PlannerDayAgenda {
        let weekday = isoWeekday(for: date)
        let dayBlocks = weeklyBlocks
            .filter { $0.weekday == weekday }
            .sorted {
                if $0.startMinute != $1.startMinute { return $0.startMinute < $1.startMinute }
                return $0.sortIndex < $1.sortIndex
            }

        let slots = dayBlocks.map { block in
            PlannerTimedSlot(
                id: block.id,
                title: block.title,
                notes: block.notes,
                kind: block.kind,
                startMinute: block.startMinute,
                endMinute: block.endMinute
            )
        }

        return PlannerDayAgenda(
            date: date,
            dayKey: dayKey(for: date),
            weekday: weekday,
            slots: slots
        )
    }

    static func buildWeekAgendas(containing date: Date, weeklyBlocks: [PlannerWeeklyBlock]) -> [PlannerDayAgenda] {
        daysInWeek(containing: date).map { buildDayAgenda(date: $0, weeklyBlocks: weeklyBlocks) }
    }

    static func casualTodayPrompt(for date: Date) -> String {
        let prompts = [
            "What's the vibe for learning today?",
            "Anything small you want to explore?",
            "What feels worth your attention today?",
            "A light plan beats no plan.",
            "What would make today feel good?"
        ]
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 0
        return prompts[day % prompts.count]
    }

    private static let shortWeekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    static func weekdayLabel(_ weekday: Int) -> String {
        guard (1...7).contains(weekday) else { return "?" }
        return shortWeekdays[weekday - 1]
    }
}

func plannerKindColor(_ kind: PlannerBlockKind) -> Color {
    switch kind {
    case .study: return SymphoTheme.colorActive.opacity(0.88)
    case .training: return SymphoTheme.colorMastered
    case .other: return SymphoTheme.secondaryText
    }
}
