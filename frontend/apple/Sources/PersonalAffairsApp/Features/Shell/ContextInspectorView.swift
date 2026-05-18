import PersonalAffairsCore
import SwiftUI

struct ContextInspectorView: View {
    @EnvironmentObject private var model: AppModel
    let selection: InspectorSelection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                switch selection {
                case .task(let id):
                    if let task = allTasks.first(where: { $0.id == id }) {
                        taskDetail(task)
                    } else {
                        unavailableCard
                    }
                case .calendarItem(let id):
                    if let item = model.calendarItems.first(where: { $0.id == id }) {
                        calendarDetail(item)
                    } else {
                        unavailableCard
                    }
                case .note(let id):
                    if let note = model.notes.first(where: { $0.id == id }) {
                        noteDetail(note)
                    } else {
                        unavailableCard
                    }
                case .project(let id):
                    if let project = model.projects.first(where: { $0.id == id }) {
                        projectDetail(project)
                    } else {
                        unavailableCard
                    }
                case .agentLog(let id):
                    if let log = model.agentLogs.first(where: { $0.id == id }) {
                        agentLogDetail(log)
                    } else {
                        unavailableCard
                    }
                case .none:
                    defaultInspector
                }
            }
            .padding(AppTheme.Spacing.lg)
        }
        .background(.thinMaterial)
    }

    private var defaultInspector: some View {
        Group {
            SurfaceView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("今日概览")
                        .font(.headline.weight(.semibold))
                    Text("弹性任务和固定时间会一起被看见，但它们仍然是两类对象。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                        miniStat("\(model.activePersonalTasks.count)", "个人")
                        miniStat("\(model.activeCompanyTasks.count)", "公司")
                        miniStat("\(model.calendarItems.count)", "固定")
                        miniStat("\(model.noProjectCompanyTasks.count)", "收件箱")
                    }
                }
            }

            SurfaceView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Label("Agent 建议", systemImage: "sparkles")
                        .font(.headline.weight(.semibold))
                    suggestionRow("\(model.noProjectCompanyTasks.count) 个公司任务还没有归入项目。", style: .warning)
                    suggestionRow("本周还有 \(upcomingItems.count) 个固定日程。", style: .company)
                    suggestionRow("\(model.notes.filter { $0.linkedTaskId == nil }.count) 条备忘之后可能会变成待办。", style: .agent)
                }
            }

            SurfaceView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("即将到来的固定日程")
                        .font(.headline.weight(.semibold))
                    if upcomingItems.isEmpty {
                        Text("近期没有固定日程。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(upcomingItems.prefix(3)) { item in
                            compactEvent(item)
                        }
                    }
                }
            }

            SurfaceView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("无项目公司任务")
                        .font(.headline.weight(.semibold))
                    if model.noProjectCompanyTasks.isEmpty {
                        Text("无项目收件箱已清空。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedForFocus(model.noProjectCompanyTasks).prefix(3)) { task in
                            Text(task.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }

    private var unavailableCard: some View {
        EmptyStateCardView(
            title: "项目已不可用",
            message: "请刷新数据，或选择另一个项目。",
            systemImage: "questionmark.folder"
        )
    }

    private func taskDetail(_ task: TaskItem) -> some View {
        SurfaceView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Label("待办", systemImage: "checklist")
                    .font(.headline.weight(.semibold))
                Text(task.title)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let description = task.description?.trimmedOrNil {
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                FlowPills {
                    PillView(text: task.priority.label, style: task.priority.pillStyle)
                    PillView(text: task.status.label, style: task.status == .done ? .success : .neutral)
                    PillView(text: spaceStyle(task.spaceId) == .personal ? "个人" : "公司", style: spaceStyle(task.spaceId))
                    if let dueDate = task.dueDate {
                        PillView(text: "截止 \(dueDate)", style: .warningSubtle)
                    }
                    if let project = model.projectName(for: task.projectId) {
                        PillView(text: project, style: .company)
                    }
                }
                HStack {
                    Button(task.status == .done ? "重新打开" : "完成") {
                        mutateTask(task.status == .done ? .reopen : .complete, task)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("归档") {
                        mutateTask(.archive, task)
                    }
                }
            }
        }
    }

    private func calendarDetail(_ item: CalendarItem) -> some View {
        SurfaceView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Label("固定日程", systemImage: item.type.systemImage)
                    .font(.headline.weight(.semibold))
                Text(item.title)
                    .font(.title3.weight(.semibold))
                if let description = item.description?.trimmedOrNil {
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                FlowPills {
                    PillView(text: model.spaceLabel(for: item.spaceId), style: spaceStyle(item.spaceId))
                    PillView(text: item.type.label, style: item.type.pillStyle)
                    PillView(text: item.allDay ? (item.startDate ?? "全天") : (item.startAt?.shortDateTime ?? "定时"), style: .neutral)
                    if let recurrence = item.recurrence, recurrence != .none {
                        PillView(text: recurrence.label, style: .agent, systemImage: "repeat")
                    }
                    if let project = model.projectName(for: item.projectId) {
                        PillView(text: project, style: .company)
                    }
                }
                Button(role: .destructive) {
                    deleteCalendarItem(item)
                } label: {
                    Label("删除固定日程", systemImage: "trash")
                }
            }
        }
    }

    private func noteDetail(_ note: Note) -> some View {
        SurfaceView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Label("灵感 / 备忘", systemImage: note.type.systemImage)
                    .font(.headline.weight(.semibold))
                Text(note.title?.trimmedOrNil ?? "未命名")
                    .font(.title3.weight(.semibold))
                Text(note.body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                FlowPills {
                    PillView(text: note.type.label, style: note.type.pillStyle)
                    if note.linkedTaskId != nil {
                        PillView(text: "已转待办", style: .success)
                    }
                    if note.source == "agent" {
                        PillView(text: "Agent", style: .agent, systemImage: "sparkles")
                    }
                }
                HStack {
                    Button("转为待办") {
                        convert(note)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("归档") {
                        archive(note)
                    }
                }
            }
        }
    }

    private func projectDetail(_ project: Project) -> some View {
        SurfaceView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Label("公司项目", systemImage: "folder")
                    .font(.headline.weight(.semibold))
                Text(project.name)
                    .font(.title3.weight(.semibold))
                if let description = project.description?.trimmedOrNil {
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                FlowPills {
                    PillView(text: project.status.label, style: project.status.pillStyle)
                    PillView(text: "\(projectTasks(project.id).count) 个进行中任务", style: .company)
                    if let targetDate = project.targetDate {
                        PillView(text: "目标 \(targetDate)", style: .warningSubtle)
                    }
                }
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("任务预览")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                    ForEach(sortedForFocus(projectTasks(project.id)).prefix(4)) { task in
                        Text(task.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    private func agentLogDetail(_ log: AgentActionLog) -> some View {
        SurfaceView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Label("Agent 操作", systemImage: "sparkles")
                    .font(.headline.weight(.semibold))
                Text(log.actionType)
                    .font(.title3.weight(.semibold))
                FlowPills {
                    PillView(text: log.status, style: log.status == "success" ? .success : .warning)
                    if let targetType = log.targetType {
                        PillView(text: targetType, style: .neutral)
                    }
                }
                if let error = log.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.dangerAccent)
                }
                Text(log.createdAt.shortDateTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
    }

    private func suggestionRow(_ text: String, style: PillStyle) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Circle()
                .fill(style.color)
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func compactEvent(_ item: CalendarItem) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: item.type.systemImage)
                .foregroundStyle(item.type.pillStyle.color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                Text(item.allDay ? (item.startDate ?? "全天") : (item.startAt?.shortDateTime ?? "定时"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var allTasks: [TaskItem] {
        model.personalTasks + model.companyTasks
    }

    private var upcomingItems: [CalendarItem] {
        let now = Date()
        let upper = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        return sortedCalendarItems(model.calendarItems).filter { item in
            guard let date = calendarSortDate(item) else { return false }
            return date >= Calendar.current.startOfDay(for: now) && date <= upper
        }
    }

    private func projectTasks(_ projectId: String) -> [TaskItem] {
        model.companyTasks.filter { $0.projectId == projectId && $0.status == .active }
    }

    private func spaceStyle(_ spaceId: String) -> PillStyle {
        model.spaces.first { $0.id == spaceId }?.type == .personal ? .personal : .company
    }

    private enum TaskMutation {
        case complete
        case reopen
        case archive
    }

    private func mutateTask(_ mutation: TaskMutation, _ task: TaskItem) {
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

    private func deleteCalendarItem(_ item: CalendarItem) {
        Task {
            await model.run {
                _ = try await model.calendarRepository.delete(id: item.id)
                try await model.loadAllData()
            }
        }
    }

    private func convert(_ note: Note) {
        Task {
            await model.run {
                let title = note.title?.trimmedOrNil ?? String(note.body.prefix(48))
                _ = try await model.noteRepository.convertToTask(
                    noteId: note.id,
                    request: ConvertNoteToTaskRequest(title: title, priority: .medium)
                )
                try await model.loadAllData()
            }
        }
    }

    private func archive(_ note: Note) {
        Task {
            await model.run {
                _ = try await model.noteRepository.archive(id: note.id)
                try await model.loadAllData()
            }
        }
    }
}

private struct FlowPills<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 6) {
            content
        }
    }
}
