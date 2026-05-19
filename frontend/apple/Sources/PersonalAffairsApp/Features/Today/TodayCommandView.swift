import PersonalAffairsCore
import SwiftUI

struct TodayCommandView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.workbenchLayout) private var layout
    var selection: InspectorSelection? = nil
    let selectTask: (TaskItem) -> Void
    let selectCalendarItem: (CalendarItem) -> Void
    let jumpToSection: (AppSection) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                SectionHeaderView(
                    style: .hero,
                    eyebrow: todayEyebrow,
                    title: "今天不要排满，只挑最重要的三件事。",
                    subtitle: "弹性待办在 Focus Stack；必须发生的时间进入 Fixed Schedule；Agent 只做整理和建议。",
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

                if layout.usesWideColumns {
                    HStack(alignment: .top, spacing: AppTheme.Spacing.lg) {
                        focusStack
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                            scheduleColumn
                            agentSuggestionPanel
                        }
                        .frame(width: min(360, max(300, layout.centerWidth * 0.34)), alignment: .topLeading)
                    }
                } else {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                        focusStack
                        scheduleColumn
                        agentSuggestionPanel
                    }
                }

                looseEndsStrip
            }
            .padding(layout.pagePadding)
        }
    }

    private var focusStack: some View {
        SurfaceView(style: .elevated) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Focus Stack")
                            .font(.headline.weight(.semibold))
                        Text("先处理少数弹性事项；截止日期只影响优先级，不会自动进入日历。")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    Spacer()
                    Button("查看全部") { jumpToSection(.personalTasks) }
                        .font(.caption.weight(.semibold))
                }

                taskSection(
                    title: "个人 Top 3",
                    tasks: Array(sortedForFocus(model.activePersonalTasks).prefix(3)),
                    spaceLabel: "个人",
                    spaceStyle: .personal,
                    empty: "个人焦点已清空。"
                )
                taskSection(
                    title: "公司 Top 3",
                    tasks: Array(sortedForFocus(model.activeCompanyTasks).prefix(3)),
                    spaceLabel: "公司",
                    spaceStyle: .company,
                    empty: "公司焦点已清空。"
                )
            }
        }
    }

    private var scheduleColumn: some View {
        FixedSchedulePanel(
            selection: selection,
            todayItems: todayItems,
            upcomingItems: upcomingItems,
            selectCalendarItem: selectCalendarItem,
            showMore: { jumpToSection(.calendar) }
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var looseEndsStrip: some View {
        SurfaceView(style: model.noProjectCompanyTasks.isEmpty ? .subtle : .warning) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                Image(systemName: "tray")
                    .foregroundStyle(AppTheme.Colors.warningAccent)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.Colors.warningAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Company Loose Ends")
                        .font(.callout.weight(.semibold))
                    Text(model.noProjectCompanyTasks.isEmpty ? "无项目收件箱已清空。" : "\(model.noProjectCompanyTasks.count) 个公司任务还没有归入项目。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Spacer()
                Button("整理") { jumpToSection(.companyTasks) }
                    .font(.caption.weight(.semibold))
            }
        }
    }

    private var agentSuggestionPanel: some View {
        SurfaceView(style: .tinted(.agent)) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Label("Agent Suggestions", systemImage: "sparkles")
                    .font(.headline.weight(.semibold))
                suggestion("\(model.noProjectCompanyTasks.count) 个公司任务没有项目归属", action: "整理")
                suggestion("\(upcomingItems.count) 个固定日程在未来一周", action: "查看")
                suggestion("\(model.notes.filter { $0.linkedTaskId == nil }.count) 条灵感还没有转行动", action: "生成候选")
            }
        }
    }

    @ViewBuilder
    private func taskSection(title: String, tasks: [TaskItem], spaceLabel: String, spaceStyle: PillStyle, empty: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .textCase(.uppercase)
            if tasks.isEmpty {
                EmptyStateInline(title: empty, message: "用 Quick Capture 记录新的弹性事项。")
            } else {
                TaskCardList {
                    ForEach(tasks) { task in
                        TaskCardView(
                            task: task,
                            projectName: model.projectName(for: task.projectId),
                            spaceStyle: spaceStyle,
                            spaceLabel: spaceLabel,
                            isSelected: selection == .task(task.id),
                            compact: true,
                            onSelect: { selectTask(task) },
                            onComplete: { mutateTask(.complete, task) },
                            onReopen: { mutateTask(.reopen, task) },
                            onArchive: { mutateTask(.archive, task) }
                        )
                    }
                }
            }
        }
    }

    private func suggestion(_ text: String, action: String) -> some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Circle()
                .fill(AppTheme.Colors.agentAccent)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .lineLimit(2)
            Spacer(minLength: AppTheme.Spacing.sm)
            Text(action)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.agentAccent)
        }
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

    private enum Mutation {
        case complete
        case reopen
        case archive
    }

    private func mutateTask(_ mutation: Mutation, _ task: TaskItem) {
        Task {
            await model.run {
                switch mutation {
                case .complete:
                    _ = try await model.taskRepository.complete(id: task.id)
                case .reopen:
                    _ = try await model.taskRepository.reopen(id: task.id)
                case .archive:
                    _ = try await model.taskRepository.archive(id: task.id)
                }
                try await model.loadAllData()
            }
        }
    }
}
