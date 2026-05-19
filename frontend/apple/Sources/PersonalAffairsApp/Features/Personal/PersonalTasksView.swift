import PersonalAffairsCore
import SwiftUI

struct PersonalTasksView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.workbenchLayout) private var layout
    @State private var status: TaskStatus = .active
    @State private var search = ""
    @State private var showingNewTask = false
    var selection: InspectorSelection? = nil
    var onSelectTask: (TaskItem) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                header
                if status == .active {
                    focusPreview
                }
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
                                isSelected: selection == .task(task.id),
                                onSelect: { onSelectTask(task) },
                                onComplete: { complete(task) },
                                onReopen: { reopen(task) },
                                onArchive: { archive(task) }
                            )
                        }
                    }
                }
            }
            .padding(layout.pagePadding)
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
                    model.personalTasks = try await model.taskRepository.list(query: personalQuery(spaceId: space.id))
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
        SurfaceView(style: .subtle, padding: AppTheme.Spacing.md) {
            ViewThatFits(in: .horizontal) {
                horizontalFilterBar
                verticalFilterBar
            }
        }
    }

    private var horizontalFilterBar: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            statusPicker
                .frame(width: min(260, max(220, layout.centerWidth * 0.30)))
            TextField("搜索", text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(width: layout.narrowControlWidth)
                .onSubmit {
                    Task { await model.reloadPersonalTasks(status: status, search: search.trimmedOrNil) }
                }
            Spacer()
            PillView(text: "个人不使用项目", style: .personal)
        }
    }

    private var verticalFilterBar: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            statusPicker
            TextField("搜索", text: $search)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    Task { await model.reloadPersonalTasks(status: status, search: search.trimmedOrNil) }
                }
            PillView(text: "个人不使用项目", style: .personal)
        }
    }

    private var statusPicker: some View {
        Picker("状态", selection: $status) {
            ForEach(TaskStatus.allCases) { status in
                Text(status.label).tag(status)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: status) { newValue in
            Task { await model.reloadPersonalTasks(status: newValue, search: search.trimmedOrNil) }
        }
    }

    private var focusPreview: some View {
        SurfaceView(style: .tinted(.personal)) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack {
                    Text("个人 Focus Preview")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    PillView(text: "Top 3", style: .personal)
                }
                TaskCardList {
                    ForEach(PersonalTasksViewState.focusTasks(model.personalTasks)) { task in
                        TaskCardView(
                            task: task,
                            projectName: nil,
                            spaceStyle: .personal,
                            spaceLabel: "个人",
                            isSelected: selection == .task(task.id),
                            compact: true,
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

    private func complete(_ task: TaskItem) {
        Task {
            await model.run {
                _ = try await model.taskRepository.complete(id: task.id)
                guard let space = model.personalSpace else { return }
                model.personalTasks = try await model.taskRepository.list(query: personalQuery(spaceId: space.id))
            }
        }
    }

    private func reopen(_ task: TaskItem) {
        Task {
            await model.run {
                _ = try await model.taskRepository.reopen(id: task.id)
                guard let space = model.personalSpace else { return }
                model.personalTasks = try await model.taskRepository.list(query: personalQuery(spaceId: space.id))
            }
        }
    }

    private func archive(_ task: TaskItem) {
        Task {
            await model.run {
                _ = try await model.taskRepository.archive(id: task.id)
                guard let space = model.personalSpace else { return }
                model.personalTasks = try await model.taskRepository.list(query: personalQuery(spaceId: space.id))
            }
        }
    }

    private func personalQuery(spaceId: String) -> TaskListQuery {
        PersonalTasksViewState.query(
            personalSpaceId: spaceId,
            status: status,
            search: search.trimmedOrNil
        )
    }
}

struct TaskDraft {
    var title = ""
    var description = ""
    var priority: TaskPriority = .medium
    var hasDueDate = false
    var dueDate = Date()
    var projectId: String?

    init(
        title: String = "",
        description: String = "",
        priority: TaskPriority = .medium,
        dueDateString: String? = nil,
        projectId: String? = nil
    ) {
        self.title = title
        self.description = description
        self.priority = priority
        let parsedDueDate = parsedDateOnly(dueDateString)
        self.hasDueDate = parsedDueDate != nil
        self.dueDate = parsedDueDate ?? Date()
        self.projectId = projectId
    }

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
        EditorSheetView(
            title: title,
            subtitle: allowsProject ? "公司待办可以留在无项目，也可以关联到项目。" : "个人待办不使用项目。",
            isActionDisabled: draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            cancel: { dismiss() },
            action: {
                Task {
                    await save(draft)
                    dismiss()
                }
            }
        ) {
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
        }
    }
}
