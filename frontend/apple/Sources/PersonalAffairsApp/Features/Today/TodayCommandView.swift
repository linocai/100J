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
            VStack(alignment: .leading, spacing: 18) {
                header
                topThreeSection
                upcomingSection
                looseEndsSection
            }
            .padding(layout.pagePadding)
        }
        .onAppear {
            model.todayViewModel.refresh()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(todayEyebrow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Today")
                    .font(.largeTitle.weight(.bold))
                Text("只看三件焦点、接下来要发生的事，以及需要整理的尾巴。")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.universalComposerViewModel.open()
            } label: {
                Label("新建", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var topThreeSection: some View {
        GroupBox {
            if model.todayViewModel.topThree.isEmpty {
                EmptyStateInline(title: "暂无 Top 3", message: "按 ⌘K 捕捉一个真正要推进的事项。")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.todayViewModel.topThree) { task in
                        TodayTaskRow(
                            task: task,
                            projectName: model.projectName(for: task.projectId),
                            isSelected: selection == .task(task.id),
                            select: { selectTask(task) },
                            toggle: { Task { await model.toggleTaskDone(task) } }
                        )
                        Divider()
                    }
                }
            }
        } label: {
            SectionLabel(title: "Top 3", subtitle: "今天最值得推进的三件事。", systemImage: "scope")
        }
    }

    private var upcomingSection: some View {
        GroupBox {
            if model.todayViewModel.upcoming.isEmpty {
                EmptyStateInline(title: "今天没有固定日程", message: "有固定时间才进入 Calendar。")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.todayViewModel.upcoming) { schedule in
                        Button {
                            selectCalendarItem(schedule.item)
                        } label: {
                            HStack(spacing: 12) {
                                Text(schedule.timeLabel)
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(Color.indigo)
                                    .frame(width: 54, alignment: .leading)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(schedule.item.title)
                                        .font(.callout.weight(.semibold))
                                    Text(schedule.item.type.label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        } label: {
            HStack {
                SectionLabel(title: "接下来", subtitle: "固定时间和固定日期。", systemImage: "calendar")
                Spacer()
                Button("打开 Calendar") { jumpToSection(.calendar) }
                    .font(.caption.weight(.semibold))
            }
        }
    }

    private var looseEndsSection: some View {
        GroupBox {
            if model.todayViewModel.looseEnds.isEmpty {
                EmptyStateInline(title: "Loose Ends 已清空", message: "无项目任务和未转行动的灵感会出现在这里。")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.todayViewModel.looseEnds) { item in
                        Button {
                            selectLooseEnd(item)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.kind == .task ? "tray" : "note.text")
                                    .foregroundStyle(item.kind == .task ? Color.orange : Color.purple)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.callout.weight(.semibold))
                                        .lineLimit(2)
                                    Text(item.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        } label: {
            HStack {
                SectionLabel(title: "Loose Ends", subtitle: "还没归位的公司任务和灵感。", systemImage: "tray")
                Spacer()
                Button("整理") { jumpToSection(.plan) }
                    .font(.caption.weight(.semibold))
            }
        }
    }

    private var todayEyebrow: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "EEEE · M月d日"
        return formatter.string(from: Date())
    }

    private func selectLooseEnd(_ item: TodayLooseEnd) {
        switch item.kind {
        case .task:
            let taskID = item.id.replacingOccurrences(of: "task-", with: "")
            if let task = model.companyTasks.first(where: { $0.id == taskID }) {
                selectTask(task)
            }
        case .note:
            jumpToSection(.plan)
        }
    }
}

private struct SectionLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.indigo)
        }
    }
}

private struct TodayTaskRow: View {
    let task: TaskItem
    let projectName: String?
    let isSelected: Bool
    let select: () -> Void
    let toggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: toggle) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.status == .done ? Color.green : .secondary)
            }
            .buttonStyle(.plain)

            Button(action: select) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.indigo : .primary)
                        .lineLimit(2)
                    WrappingHStack(spacing: 6, rowSpacing: 5) {
                        PillView(text: task.priority.label, style: task.priority.pillStyle)
                        if let dueDate = task.dueDate {
                            PillView(text: "截止 \(dueDate)", style: .warningSubtle)
                        }
                        if let projectName {
                            PillView(text: projectName, style: .company, systemImage: "folder")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
    }
}
