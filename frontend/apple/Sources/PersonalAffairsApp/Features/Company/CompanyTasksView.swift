import PersonalAffairsCore
import SwiftUI

struct CompanyTasksView: View {
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
                EmptyStateView(title: "No company tasks", message: "Project work and no-project company tasks share this entry.")
            } else {
                List(groupedTasks, id: \.key) { group in
                    Section(group.key) {
                        ForEach(group.tasks) { task in
                            TaskRow(
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
            TaskFormView(title: "New Company Task", projects: model.projects, allowsProject: true) { draft in
                guard let space = model.companySpace else { return }
                await model.run {
                    _ = try await model.taskRepository.create(
                        TaskCreateRequest(
                            spaceId: space.id,
                            projectId: draft.projectId,
                            title: draft.title,
                            description: draft.description.trimmedOrNil,
                            priority: draft.priority,
                            dueDate: draft.dueDate.trimmedOrNil
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
            ToolbarTitle(title: "Company Tasks", subtitle: "All company work, including project and no-project tasks.")
            Spacer()
            Picker("Status", selection: $status) {
                ForEach(TaskStatus.allCases) { status in
                    Text(status.label).tag(status)
                }
            }
            .frame(width: 130)
            .onChange(of: status) { _ in Task { await reload() } }

            Picker("Scope", selection: $scope) {
                Text("All").tag("all")
                Text("No Project").tag("no_project")
                Text("With Project").tag("with_project")
                Text("Project").tag("project")
            }
            .frame(width: 150)
            .onChange(of: scope) { _ in Task { await reload() } }

            if scope == "project" {
                Picker("Project", selection: $selectedProjectId) {
                    Text("Choose").tag(Optional<String>.none)
                    ForEach(model.projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
                .frame(width: 180)
                .onChange(of: selectedProjectId) { _ in Task { await reload() } }
            }

            TextField("Search", text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)
                .onSubmit { Task { await reload() } }

            Button {
                showingNewTask = true
            } label: {
                Label("New Task", systemImage: "plus")
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

