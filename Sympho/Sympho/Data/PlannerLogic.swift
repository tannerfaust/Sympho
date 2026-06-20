//
//  PlannerLogic.swift
//  Sympho
//

import Foundation
import SwiftUI

struct PlannerStudyEntry: Identifiable, Sendable {
    let id: UUID
    let title: String
    let targetKind: PlannerTargetKind
    let durationMinutes: Int
    let iconName: String
}

struct PlannerDayPlan: Identifiable, Sendable {
    var id: String { dayKey }
    let date: Date
    let dayKey: String
    let weekday: Int
    let entries: [PlannerStudyEntry]
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

    static func daysInCurrentWeek(containing date: Date = Date()) -> [Date] {
        var cal = calendar
        cal.firstWeekday = 2
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func formatDuration(minutes: Int) -> String {
        let clamped = max(15, minutes)
        if clamped < 60 { return "\(clamped)m" }
        let hours = clamped / 60
        let remainder = clamped % 60
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }

    static func resolveTitle(
        for block: PlannerWeeklyBlock,
        domains: [Domain],
        projects: [Project],
        readingItems: [ReadingListItem],
        resources: [Resource]
    ) -> String {
        if block.targetKind == .domain,
           let id = block.linkedDomainID,
           let domain = domains.first(where: { $0.id == id }) {
            return domain.title
        }
        if block.targetKind == .project,
           let id = block.linkedProjectID,
           let project = projects.first(where: { $0.id == id }) {
            return project.title
        }
        if block.targetKind == .reading,
           let id = block.linkedReadingItemID,
           let item = readingItems.first(where: { $0.id == id }) {
            return item.title
        }
        if block.targetKind == .library,
           let id = block.linkedResourceID,
           let resource = resources.first(where: { $0.id == id }) {
            return resource.title
        }
        let trimmed = block.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    static func resolveIconName(
        for block: PlannerWeeklyBlock,
        resources: [Resource]
    ) -> String {
        if block.targetKind == .library,
           let id = block.linkedResourceID,
           let resource = resources.first(where: { $0.id == id }) {
            return resource.resourceType.iconName
        }
        return block.targetKind.iconName
    }

    static func resolveEntry(
        for block: PlannerWeeklyBlock,
        domains: [Domain],
        projects: [Project],
        readingItems: [ReadingListItem],
        resources: [Resource]
    ) -> PlannerStudyEntry {
        PlannerStudyEntry(
            id: block.id,
            title: resolveTitle(
                for: block,
                domains: domains,
                projects: projects,
                readingItems: readingItems,
                resources: resources
            ),
            targetKind: block.targetKind,
            durationMinutes: block.durationMinutes > 0 ? block.durationMinutes : max(15, block.endMinute - block.startMinute),
            iconName: resolveIconName(for: block, resources: resources)
        )
    }

    static func buildDayPlan(
        date: Date,
        weeklyBlocks: [PlannerWeeklyBlock],
        domains: [Domain],
        projects: [Project],
        readingItems: [ReadingListItem],
        resources: [Resource]
    ) -> PlannerDayPlan {
        let weekday = isoWeekday(for: date)
        let dayBlocks = weeklyBlocks
            .filter { $0.weekday == weekday }
            .sorted {
                if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
                return $0.createdAt < $1.createdAt
            }

        let entries = dayBlocks.map {
            resolveEntry(
                for: $0,
                domains: domains,
                projects: projects,
                readingItems: readingItems,
                resources: resources
            )
        }

        return PlannerDayPlan(
            date: date,
            dayKey: dayKey(for: date),
            weekday: weekday,
            entries: entries
        )
    }

    static func buildCurrentWeekPlans(
        weeklyBlocks: [PlannerWeeklyBlock],
        domains: [Domain],
        projects: [Project],
        readingItems: [ReadingListItem],
        resources: [Resource],
        referenceDate: Date = Date()
    ) -> [PlannerDayPlan] {
        daysInCurrentWeek(containing: referenceDate).map {
            buildDayPlan(
                date: $0,
                weeklyBlocks: weeklyBlocks,
                domains: domains,
                projects: projects,
                readingItems: readingItems,
                resources: resources
            )
        }
    }

    static func todayPlan(
        weeklyBlocks: [PlannerWeeklyBlock],
        domains: [Domain],
        projects: [Project],
        readingItems: [ReadingListItem],
        resources: [Resource],
        referenceDate: Date = Date()
    ) -> PlannerDayPlan {
        buildDayPlan(
            date: referenceDate,
            weeklyBlocks: weeklyBlocks,
            domains: domains,
            projects: projects,
            readingItems: readingItems,
            resources: resources
        )
    }

    private static let shortWeekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    static func weekdayLabel(_ weekday: Int) -> String {
        guard (1...7).contains(weekday) else { return "?" }
        return shortWeekdays[weekday - 1]
    }
}
