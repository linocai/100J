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
                .onValueChange(of: status) { _ in Task { await reload() } }

                Picker("范围", selection: $scope) {
                    Text("全部").tag("all")
                    Text("无项目").tag("no_project")
                    Text("有项目").tag("with_project")
                    Text("项目").tag("project")
                }
                .onValueChange(of: scope) { _ in Task { await reload() } }

                if scope == "project" {
                    Picker("项目", selection: $selectedProjectId) {
                        Text("选择").tag(Optional<String>.none)
                        ForEach(model.projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    .onValueChange(of: selectedProjectId) { _ in Task { await reload() } }
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
                                Task { await model.archiveTask(task) }
                            } label: {
                                Label("归档", systemImage: "archivebox")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await model.toggleTaskDone(task) }
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
                await model.createCompanyTask(draft)
            }
        }
        .sheet(item: $editingTask) { task in
            IOSTaskForm(
                title: "编辑公司待办",
                projects: model.projects,
                allowsProject: true,
                initialDraft: TaskDraft(task)
            ) { draft in
                await model.updateTask(id: task.id, draft: draft, includesProject: true)
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
        await model.reloadCompanyTasks(status: status, projectScope: scope, projectId: selectedProjectId)
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
                            Task { await model.archiveProject(project) }
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
                            Task { await model.completeProject(project) }
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
                await model.createProject(draft)
            }
        }
        .sheet(item: $editingProject) { project in
            IOSProjectForm(initialDraft: ProjectDraft(project)) { draft in
                await model.updateProject(id: project.id, draft: draft)
            }
        }
        .refreshable {
            await model.reloadProjects(status: .active)
        }
        .task {
            await model.reloadProjects(status: .active)
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
                await model.createProjectTask(draft, projectId: project.id)
                tasks = await model.loadProjectTasks(projectId: project.id)
            }
        }
        .task {
            tasks = await model.loadProjectTasks(projectId: project.id)
        }
    }
}
#endif
