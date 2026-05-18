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
                    title: "今日指挥台",
                    subtitle: "弹性事项留在待办，固定时间进入日程。",
                    systemImage: "sparkle.magnifyingglass"
                ) {
                    HStack {
                        Button {
                            jumpToSection(.agent)
                        } label: {
                            Label("问 Agent", systemImage: "sparkles")
                        }
                        Button {
                            jumpToSection(.calendar)
                        } label: {
                            Label("新建固定日程", systemImage: "calendar.badge.plus")
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
                title: "个人焦点",
                subtitle: "个人待办保持弹性，截止日期只显示在任务卡片里。",
                tasks: Array(sortedForFocus(model.activePersonalTasks).prefix(4)),
                spaceLabel: "个人",
                spaceStyle: .personal,
                selectTask: selectTask,
                showMore: { jumpToSection(.personalTasks) }
            )

            FocusStackPanel(
                title: "公司焦点",
                subtitle: "项目任务和无项目小任务都留在公司工作台。",
                tasks: Array(sortedForFocus(model.activeCompanyTasks).prefix(4)),
                spaceLabel: "公司",
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
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "EEEE · M月d日"
        return formatter.string(from: Date())
    }
}
