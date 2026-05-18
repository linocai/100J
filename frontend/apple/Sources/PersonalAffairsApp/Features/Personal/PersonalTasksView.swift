import PersonalAffairsCore
import SwiftUI

struct PersonalTasksView: View {
    @EnvironmentObject private var model: AppModel
    @State private var status: TaskStatus = .active
    @State private var search = ""
    @State private var showingNewTask = false
    var onSelectTask: (TaskItem) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                header
                SurfaceView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        filterBar
                        if model.personalTasks.isEmpty {
                            EmptyStateCardView(
                                title: "暂无个人待办",
                                message: "待办是你可以自行安排时间处理的弹性事项。",
                                systemImage: "checklist"
                            )
                        } else {
                            TaskCardList {
                                ForEach(model.personalTasks) { task in
                                    TaskCardView(
                                        task: task,
                                        projectName: nil,
                                        spaceStyle: .personal,
                                        spaceLabel: "个人",
                                        onSelect: { onSelectTask(task) },
                                        onComplete: { complete(task) },
                                        onReopen: { reopen(task) },
                                        onArchive: { archive(task) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.Spacing.xl)
        }
        .sheet(isPresented: $showingNewTask) {
            TaskFormView(title: "新建个人待办", projects: [], allowsProject: false) { draft in
                guard let space = model.personalSpace else { return }
                await model.run {
                    _ = try await model.taskRepository.create(
                        TaskCreateRequest(
                            spaceId: space.id,
                            title: draft.title,
                            description: draft.description.trimmedOrNil,
                            priority: draft.priority,
                            dueDate: draft.dueDateString
                        )
                    )
                    model.personalTasks = try await model.taskRepository.list(
                        spaceId: space.id,
                        status: status,
                        search: search.trimmedOrNil
                    )
                }
            }
        }
        .task {
            await model.reloadPersonalTasks(status: status, search: search.trimmedOrNil)
        }
    }

    private var header: some View {
        SectionHeaderView(
            eyebrow: "个人",
            title: "个人待办",
            subtitle: "个人事项保持弹性；截止日期不会自动进入日程。",
            systemImage: "checklist"
        ) {
            Button {
                showingNewTask = true
            } label: {
                Label("新建待办", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var filterBar: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Picker("状态", selection: $status) {
                ForEach(TaskStatus.allCases) { status in
                    Text(status.label).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)
            .onChange(of: status) { newValue in
                Task { await model.reloadPersonalTasks(status: newValue, search: search.trimmedOrNil) }
            }

            TextField("搜索", text: $search)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    Task { await model.reloadPersonalTasks(status: status, search: search.trimmedOrNil) }
                }
            Spacer()
            PillView(text: "个人不使用项目", style: .personal)
        }
    }

    private func complete(_ task: TaskItem) {
        Task {
            await model.run {
                _ = try await model.taskRepository.complete(id: task.id)
                guard let space = model.personalSpace else { return }
                model.personalTasks = try await model.taskRepository.list(spaceId: space.id, status: status, search: search.trimmedOrNil)
            }
        }
    }

    private func reopen(_ task: TaskItem) {
        Task {
            await model.run {
                _ = try await model.taskRepository.reopen(id: task.id)
                guard let space = model.personalSpace else { return }
                model.personalTasks = try await model.taskRepository.list(spaceId: space.id, status: status, search: search.trimmedOrNil)
            }
        }
    }

    private func archive(_ task: TaskItem) {
        Task {
            await model.run {
                _ = try await model.taskRepository.archive(id: task.id)
                guard let space = model.personalSpace else { return }
                model.personalTasks = try await model.taskRepository.list(spaceId: space.id, status: status, search: search.trimmedOrNil)
            }
        }
    }
}

struct TaskRow: View {
    let task: TaskItem
    let projectName: String?
    let complete: () -> Void
    let reopen: () -> Void
    let archive: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: task.status == .done ? reopen : complete) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.status == .done)
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack {
                    BadgeText(text: task.priority.label, color: task.priority == .urgent ? .red : .secondary)
                    BadgeText(text: task.status.label)
                    if let dueDate = task.dueDate {
                        BadgeText(text: "截止 \(dueDate)", color: .orange)
                    }
                    if let projectName {
                        BadgeText(text: projectName, color: .blue)
                    }
                    if task.source == "agent" {
                        BadgeText(text: "Agent", color: .indigo)
                    }
                }
            }
            Spacer()
            Button(action: archive) {
                Image(systemName: "archivebox")
            }
            .buttonStyle(.borderless)
            .help("归档")
        }
        .padding(.vertical, 6)
    }
}

struct TaskDraft {
    var title = ""
    var description = ""
    var priority: TaskPriority = .medium
    var hasDueDate = false
    var dueDate = Date()
    var projectId: String?

    var dueDateString: String? {
        hasDueDate ? dueDate.dayKey : nil
    }
}

struct TaskFormView: View {
    let title: String
    let projects: [Project]
    let allowsProject: Bool
    let save: (TaskDraft) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = TaskDraft()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: title, subtitle: allowsProject ? "公司待办可以留在无项目，也可以关联到项目。" : "个人待办不使用项目。")
            Form {
                TextField("标题", text: $draft.title)
                TextField("描述", text: $draft.description, axis: .vertical)
                Picker("优先级", selection: $draft.priority) {
                    ForEach(TaskPriority.allCases) { priority in
                        Text(priority.label).tag(priority)
                    }
                }
                Toggle("设置截止日期", isOn: $draft.hasDueDate)
                if draft.hasDueDate {
                    DatePicker("截止日期", selection: $draft.dueDate, displayedComponents: .date)
                }
                if allowsProject {
                    Picker("项目", selection: $draft.projectId) {
                        Text("无项目").tag(Optional<String>.none)
                        ForEach(projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    Task {
                        await save(draft)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(AppTheme.Spacing.xl)
        .frame(width: 480)
    }
}
