#if os(iOS)
import PersonalAffairsCore
import SwiftUI

struct IOSCompanyView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case tasks = "待办"
        case projects = "项目"
        var id: String { rawValue }
    }

    @State private var segment: Segment = .tasks

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                IOSScreenHeader(title: "公司", subtitle: "所有公司待办都在这里，项目只是其中一种视角。")
                Picker("公司视图", selection: $segment) {
                    ForEach(Segment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch segment {
                case .tasks:
                    IOSCompanyTasksList()
                case .projects:
                    IOSCompanyProjectsList()
                }
            }
            .navigationTitle("公司")
            .navigationBarTitleDisplayMode(.inline)
            .overlay { IOSLoadingOverlay() }
            .iosErrorAlert()
        }
    }
}

private struct IOSCompanyTasksList: View {
    @EnvironmentObject private var model: AppModel
    @State private var status: TaskStatus = .active
    @State private var scope = "all"
    @State private var selectedProjectId: String?
    @State private var showingNewTask = false
    @State private var editingTask: TaskItem?

    var body: some View {
        List {
            Section {
                Picker("状态", selection: $status) {
                    ForEach(TaskStatus.allCases) { status in
                        Text(status.label).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: status) { _ in Task { await reload() } }

                Picker("范围", selection: $scope) {
                    Text("全部").tag("all")
                    Text("无项目").tag("no_project")
                    Text("有项目").tag("with_project")
                    Text("项目").tag("project")
                }
                .onChange(of: scope) { _ in Task { await reload() } }

                if scope == "project" {
                    Picker("项目", selection: $selectedProjectId) {
                        Text("选择").tag(Optional<String>.none)
                        ForEach(model.projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    .onChange(of: selectedProjectId) { _ in Task { await reload() } }
                }
            }

            if model.companyTasks.isEmpty {
                IOSUnavailableView(title: "暂无待办", systemImage: "briefcase", message: "公司待办可以属于项目，也可以无项目。")
            } else {
                ForEach(model.companyTasks) { task in
                    IOSTaskRow(task: task, projectName: projectName(task.projectId, projects: model.projects))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingTask = task
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await archive(task) }
                            } label: {
                                Label("归档", systemImage: "archivebox")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await toggleDone(task) }
                            } label: {
                                Label(task.status == .done ? "重新打开" : "完成", systemImage: task.status == .done ? "arrow.uturn.left" : "checkmark")
                            }
                            .tint(.green)
                        }
                }
            }
        }
        .toolbar {
            Button {
                showingNewTask = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingNewTask) {
            IOSTaskForm(title: "新建公司待办", projects: model.projects, allowsProject: true) { draft in
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
        .sheet(item: $editingTask) { task in
            IOSTaskForm(
                title: "编辑公司待办",
                projects: model.projects,
                allowsProject: true,
                initialDraft: TaskDraft(
                    title: task.title,
                    description: task.description ?? "",
                    priority: task.priority,
                    dueDate: task.dueDate ?? "",
                    projectId: task.projectId
                )
            ) { draft in
                await model.run {
                    _ = try await model.taskRepository.update(
                        id: task.id,
                        request: TaskUpdateRequest(
                            projectId: draft.projectId,
                            title: draft.title,
                            description: draft.description.trimmedOrNil,
                            priority: draft.priority,
                            dueDate: draft.dueDate.trimmedOrNil
                        )
                    )
                    await reload()
                }
            }
        }
        .refreshable { await reload() }
        .task {
            if model.projects.isEmpty {
                await model.reloadProjects(status: .active)
            }
            await reload()
        }
    }

    private func reload() async {
        await model.reloadCompanyTasks(
            status: status,
            projectScope: scope == "all" || scope == "project" ? nil : scope,
            projectId: scope == "project" ? selectedProjectId : nil
        )
    }

    private func toggleDone(_ task: TaskItem) async {
        await model.run {
            if task.status == .done {
                _ = try await model.taskRepository.reopen(id: task.id)
            } else {
                _ = try await model.taskRepository.complete(id: task.id)
            }
            try await model.loadAllData()
        }
    }

    private func archive(_ task: TaskItem) async {
        await model.run {
            _ = try await model.taskRepository.archive(id: task.id)
            try await model.loadAllData()
        }
    }
}

private struct IOSCompanyProjectsList: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingNewProject = false
    @State private var editingProject: Project?

    var body: some View {
        List {
            if model.projects.isEmpty {
                IOSUnavailableView(title: "暂无项目", systemImage: "folder", message: "v1 中项目只属于公司空间。")
            } else {
                ForEach(model.projects) { project in
                    NavigationLink {
                        IOSProjectDetail(project: project)
                    } label: {
                        IOSProjectRow(project: project)
                    }
                    .contextMenu {
                        Button("编辑") {
                            editingProject = project
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await archive(project) }
                        } label: {
                            Label("归档", systemImage: "archivebox")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            editingProject = project
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        .tint(.blue)

                        Button {
                            Task { await complete(project) }
                        } label: {
                            Label("完成", systemImage: "checkmark")
                        }
                        .tint(.green)
                    }
                }
            }
        }
        .toolbar {
            Button {
                showingNewProject = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingNewProject) {
            IOSProjectForm { draft in
                guard let space = model.companySpace else { return }
                await model.run {
                    _ = try await model.projectRepository.create(
                        ProjectCreateRequest(
                            spaceId: space.id,
                            name: draft.name,
                            description: draft.description.trimmedOrNil,
                            startDate: draft.startDate.trimmedOrNil,
                            targetDate: draft.targetDate.trimmedOrNil
                        )
                    )
                    model.projects = try await model.projectRepository.list(spaceId: space.id, status: .active)
                }
            }
        }
        .sheet(item: $editingProject) { project in
            IOSProjectForm(
                initialDraft: ProjectDraft(
                    name: project.name,
                    description: project.description ?? "",
                    startDate: project.startDate ?? "",
                    targetDate: project.targetDate ?? ""
                )
            ) { draft in
                await model.run {
                    _ = try await model.projectRepository.update(
                        id: project.id,
                        request: ProjectUpdateRequest(
                            name: draft.name,
                            description: draft.description.trimmedOrNil,
                            startDate: draft.startDate.trimmedOrNil,
                            targetDate: draft.targetDate.trimmedOrNil
                        )
                    )
                    guard let space = model.companySpace else { return }
                    model.projects = try await model.projectRepository.list(spaceId: space.id, status: .active)
                }
            }
        }
        .refreshable {
            await model.reloadProjects(status: .active)
        }
        .task {
            await model.reloadProjects(status: .active)
        }
    }

    private func complete(_ project: Project) async {
        await model.run {
            _ = try await model.projectRepository.complete(id: project.id)
            guard let space = model.companySpace else { return }
            model.projects = try await model.projectRepository.list(spaceId: space.id, status: .active)
        }
    }

    private func archive(_ project: Project) async {
        await model.run {
            _ = try await model.projectRepository.archive(id: project.id)
            guard let space = model.companySpace else { return }
            model.projects = try await model.projectRepository.list(spaceId: space.id, status: .active)
        }
    }
}

private struct IOSProjectDetail: View {
    @EnvironmentObject private var model: AppModel
    let project: Project
    @State private var tasks: [TaskItem] = []
    @State private var showingNewTask = false

    var body: some View {
        List {
            Section("项目") {
                IOSProjectRow(project: project)
            }
            Section("进行中任务") {
                if tasks.isEmpty {
                    IOSUnavailableView(title: "暂无任务", systemImage: "checklist", message: "项目任务会显示在这里。")
                } else {
                    ForEach(tasks) { task in
                        IOSTaskRow(task: task, projectName: nil)
                    }
                }
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                showingNewTask = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingNewTask) {
            IOSTaskForm(
                title: "新建项目待办",
                projects: [project],
                allowsProject: false,
                initialDraft: TaskDraft(projectId: project.id)
            ) { draft in
                guard let space = model.companySpace else { return }
                await model.run {
                    _ = try await model.taskRepository.create(
                        TaskCreateRequest(
                            spaceId: space.id,
                            projectId: project.id,
                            title: draft.title,
                            description: draft.description.trimmedOrNil,
                            priority: draft.priority,
                            dueDate: draft.dueDate.trimmedOrNil
                        )
                    )
                    tasks = try await model.projectRepository.tasks(projectId: project.id, status: .active)
                }
            }
        }
        .task {
            await model.run {
                tasks = try await model.projectRepository.tasks(projectId: project.id, status: .active)
            }
        }
    }
}
#endif
