import PersonalAffairsCore
import SwiftUI

struct TodayCommandView: View {
    @EnvironmentObject private var model: AppModel
    let selectTask: (TaskItem) -> Void
    let selectCalendarItem: (CalendarItem) -> Void
    let jumpToSection: (AppSection) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                SectionHeaderView(
                    eyebrow: todayEyebrow,
                    title: "Today Command",
                    subtitle: "Flexible tasks stay flexible. Fixed time stays fixed.",
                    systemImage: "sparkle.magnifyingglass"
                ) {
                    HStack {
                        Button {
                            jumpToSection(.agent)
                        } label: {
                            Label("Ask Agent", systemImage: "sparkles")
                        }
                        Button {
                            jumpToSection(.calendar)
                        } label: {
                            Label("New Fixed Item", systemImage: "calendar.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                TodayMetricsPanel(
                    personalCount: model.activePersonalTasks.count,
                    companyCount: model.activeCompanyTasks.count,
                    fixedCount: todayItems.count + upcomingItems.count,
                    looseCount: model.noProjectCompanyTasks.count
                )

                GeometryReader { geometry in
                    let columns = geometry.size.width >= 860
                    if columns {
                        HStack(alignment: .top, spacing: AppTheme.Spacing.lg) {
                            focusColumn
                            scheduleColumn
                        }
                    } else {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                            focusColumn
                            scheduleColumn
                        }
                    }
                }
                .frame(minHeight: 560)
            }
            .padding(AppTheme.Spacing.xl)
        }
    }

    private var focusColumn: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            FocusStackPanel(
                title: "Personal Focus",
                subtitle: "Flexible personal tasks. Due dates stay in task cards.",
                tasks: Array(sortedForFocus(model.activePersonalTasks).prefix(4)),
                spaceLabel: "Personal",
                spaceStyle: .personal,
                selectTask: selectTask,
                showMore: { jumpToSection(.personalTasks) }
            )

            FocusStackPanel(
                title: "Company Focus",
                subtitle: "Project work and no-project tasks stay in one company surface.",
                tasks: Array(sortedForFocus(model.activeCompanyTasks).prefix(4)),
                spaceLabel: "Company",
                spaceStyle: .company,
                selectTask: selectTask,
                showMore: { jumpToSection(.companyTasks) }
            )

            LooseEndsPanel(
                tasks: Array(sortedForFocus(model.noProjectCompanyTasks).prefix(5)),
                selectTask: selectTask,
                showMore: { jumpToSection(.companyTasks) }
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var scheduleColumn: some View {
        FixedSchedulePanel(
            todayItems: todayItems,
            upcomingItems: upcomingItems,
            selectCalendarItem: selectCalendarItem,
            showMore: { jumpToSection(.calendar) }
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var todayItems: [CalendarItem] {
        let today = Date().dayKey
        return sortedCalendarItems(model.calendarItems).filter { item in
            if item.allDay {
                return item.startDate == today
            }
            guard let startAt = item.startAt else { return false }
            return Calendar.current.isDateInToday(startAt)
        }
    }

    private var upcomingItems: [CalendarItem] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        let upper = calendar.date(byAdding: .day, value: 7, to: todayStart) ?? todayStart

        return sortedCalendarItems(model.calendarItems).filter { item in
            guard let date = calendarSortDate(item) else { return false }
            return date >= tomorrowStart && date <= upper
        }
    }

    private var todayEyebrow: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE · MMM d"
        return formatter.string(from: Date())
    }
}
