//
//  SidebarTodayPlanCard.swift
//  Sympho
//

#if os(macOS)
import SwiftUI
import SwiftData

struct SidebarTodayPlanCard: View {
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

    private var todayPlan: PlannerDayPlan {
        PlannerLogic.todayPlan(
            weeklyBlocks: weeklyBlocks,
            domains: domains,
            projects: projects,
            readingItems: readingItems,
            resources: resources
        )
    }

    private var totalMinutes: Int {
        todayPlan.entries.reduce(0) { $0 + $1.durationMinutes }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Learn today")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)

                Spacer(minLength: 0)

                if !todayPlan.entries.isEmpty {
                    Text(PlannerLogic.formatDuration(minutes: totalMinutes))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(SymphoTheme.secondaryText)
                }
            }

            if todayPlan.entries.isEmpty {
                Text("Nothing planned yet.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(todayPlan.entries) { entry in
                        HStack(spacing: 8) {
                            Image(systemName: entry.iconName)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(SymphoTheme.secondaryText)
                                .frame(width: 16)

                            Text(entry.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(SymphoTheme.primaryText)
                                .lineLimit(1)

                            Spacer(minLength: 0)

                            Text(PlannerLogic.formatDuration(minutes: entry.durationMinutes))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(SymphoTheme.tertiaryText)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SymphoTheme.elevatedCanvas.opacity(0.55))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(SymphoTheme.dividerColor.opacity(0.85), lineWidth: 1)
        }
    }
}
#endif
