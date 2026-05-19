import PersonalAffairsCore
import SwiftUI

struct LegacyCompanyTasksView: View {
    @EnvironmentObject private var model: AppModel
    @State private var status: TaskStatus = .active
    @State private var scope = "all"
    @State private var selectedProjectId: String?
    @State private var search = ""
    @State private var showingNewTask = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.companyTasks.isEmpty {
                EmptyStateView(title: "暂无公司待办", message: "项目任务和无项目小任务都从这里进入。")
            } else {
                List(groupedTasks, id: \.key) { group in
                    Section(group.key) {
                        ForEach(group.tasks) { task in
                            LegacyTaskRow(
                                task: task,
                                projectName: projectName(task.projectId, projects: model.projects),
                                complete: { complete(task) },
                                reopen: { reopen(task) },
                                archive: { archive(task) }
                            )
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewTask) {
            TaskFormView(title: "新建公司待办", projects: model.projects, allowsProject: true) { draft in
                guard let space = model.companySpace else { return }
                await model.run {
                    _ = try await model.taskRepository.create(
                        TaskCreateRequest(
                            spaceId: space.id,
                            projectId: draft.projectId,
                            title: draft.title,
                            description: draft.description.trimmedOrNil,
                            priority: draft.priority,
                            dueDate: draft.dueDateString
                        )
                    )
                    try await model.loadAllData()
                }
            }
        }
        .task { await reload() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ToolbarTitle(title: "公司待办", subtitle: "所有公司事项，包括项目任务和无项目任务。")
            Spacer()
            Picker("状态", selection: $status) {
                ForEach(TaskStatus.allCases) { status in
                    Text(status.label).tag(status)
                }
            }
            .frame(width: 130)
            .onChange(of: status) { _ in Task { await reload() } }

            Picker("范围", selection: $scope) {
                Text("全部").tag("all")
                Text("无项目").tag("no_project")
                Text("有项目").tag("with_project")
                Text("项目").tag("project")
            }
            .frame(width: 150)
            .onChange(of: scope) { _ in Task { await reload() } }

            if scope == "project" {
                Picker("项目", selection: $selectedProjectId) {
                    Text("选择").tag(Optional<String>.none)
                    ForEach(model.projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
                .frame(width: 180)
                .onChange(of: selectedProjectId) { _ in Task { await reload() } }
            }

            TextField("搜索", text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)
                .onSubmit { Task { await reload() } }

            Button {
                showingNewTask = true
            } label: {
                Label("新建待办", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var groupedTasks: [(key: String, tasks: [TaskItem])] {
        let grouped = Dictionary(grouping: model.companyTasks) { task in
            projectName(task.projectId, projects: model.projects)
        }
        return grouped.keys.sorted().map { key in
            (key, grouped[key] ?? [])
        }
    }

    private func reload() async {
        let projectId = scope == "project" ? selectedProjectId : nil
        let projectScope = scope == "project" || scope == "all" ? nil : scope
        await model.reloadCompanyTasks(
            status: status,
            projectScope: projectScope,
            projectId: projectId,
            search: search.trimmedOrNil
        )
    }

    private func complete(_ task: TaskItem) {
        Task { await mutateTask { _ = try await model.taskRepository.complete(id: task.id) } }
    }

    private func reopen(_ task: TaskItem) {
        Task { await mutateTask { _ = try await model.taskRepository.reopen(id: task.id) } }
    }

    private func archive(_ task: TaskItem) {
        Task { await mutateTask { _ = try await model.taskRepository.archive(id: task.id) } }
    }

    private func mutateTask(_ operation: @escaping () async throws -> Void) async {
        await model.run {
            try await operation()
            try await model.loadAllData()
        }
    }
}
