import PersonalAffairsCore
import SwiftUI

struct ProjectDraft {
    var name = ""
    var description = ""
    var startDate = ""
    var targetDate = ""
}

#if os(macOS)
struct CompanyProjectsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var status: ProjectStatus = .active
    @State private var showingNewProject = false
    @State private var selectedProjectId: String?
    @State private var projectTasks: [TaskItem] = []
    var onSelectProject: (Project) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                header
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: AppTheme.Spacing.md)], spacing: AppTheme.Spacing.md) {
                    ForEach(model.projects) { project in
                        ProjectCardView(
                            project: project,
                            activeTaskCount: model.companyTasks.filter { $0.projectId == project.id && $0.status == .active }.count,
                            completedTaskCount: model.companyTasks.filter { $0.projectId == project.id && $0.status == .done }.count,
                            isSelected: selectedProjectId == project.id,
                            onSelect: {
                                selectedProjectId = project.id
                                onSelectProject(project)
                                Task { await loadProjectTasks(project.id) }
                            }
                        )
                    }
                }

                ProjectDetailView(
                    project: selectedProject,
                    tasks: projectTasks,
                    complete: { project in complete(project) },
                    archive: { project in archive(project) },
                    completeTask: { task in completeTask(task) },
                    archiveTask: { task in archiveTask(task) }
                )
            }
            .padding(AppTheme.Spacing.xl)
        }
        .sheet(isPresented: $showingNewProject) {
            ProjectFormView { draft in
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
                    try await model.loadAllData()
                }
            }
        }
        .task {
            await model.reloadProjects(status: status)
        }
    }

    private var selectedProject: Project? {
        guard let selectedProjectId else { return nil }
        return model.projects.first { $0.id == selectedProjectId }
    }

    private var header: some View {
        SectionHeaderView(
            eyebrow: "Company",
            title: "Projects",
            subtitle: "Projects show the whole shape. Daily task handling stays in Company Workbench.",
            systemImage: "folder"
        ) {
            HStack {
                Picker("Status", selection: $status) {
                    ForEach(ProjectStatus.allCases) { status in
                        Text(status.label).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                .onChange(of: status) { newValue in
                    Task { await model.reloadProjects(status: newValue) }
                }

                Button {
                    showingNewProject = true
                } label: {
                    Label("New Project", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func loadProjectTasks(_ projectId: String?) async {
        guard let projectId else {
            projectTasks = []
            return
        }
        await model.run {
            projectTasks = try await model.projectRepository.tasks(projectId: projectId, status: .active)
        }
    }

    private func complete(_ project: Project) {
        Task {
            await model.run {
                _ = try await model.projectRepository.complete(id: project.id)
                try await model.loadAllData()
            }
        }
    }

    private func archive(_ project: Project) {
        Task {
            await model.run {
                _ = try await model.projectRepository.archive(id: project.id)
                try await model.loadAllData()
            }
        }
    }

    private func completeTask(_ task: TaskItem) {
        Task {
            await model.run {
                _ = try await model.taskRepository.complete(id: task.id)
                try await model.loadAllData()
            }
            await loadProjectTasks(task.projectId)
        }
    }

    private func archiveTask(_ task: TaskItem) {
        Task {
            await model.run {
                _ = try await model.taskRepository.archive(id: task.id)
                try await model.loadAllData()
            }
            await loadProjectTasks(task.projectId)
        }
    }
}

private struct ProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.name)
                .font(.headline)
            if let description = project.description, !description.isEmpty {
                Text(description)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack {
                BadgeText(text: project.status.label, color: project.status == .active ? .blue : .secondary)
                if let targetDate = project.targetDate {
                    BadgeText(text: "Target \(targetDate)", color: .orange)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct ProjectDetailView: View {
    let project: Project?
    let tasks: [TaskItem]
    let complete: (Project) -> Void
    let archive: (Project) -> Void
    let completeTask: (TaskItem) -> Void
    let archiveTask: (TaskItem) -> Void

    var body: some View {
        Group {
            if let project {
                SurfaceView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(project.name)
                                    .font(.title3.weight(.semibold))
                                Text(project.description ?? "Project detail")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            PillView(text: project.status.label, style: project.status.pillStyle)
                        }
                        HStack(spacing: 6) {
                            if let startDate = project.startDate {
                                PillView(text: "Start \(startDate)", style: .neutralSubtle)
                            }
                            if let targetDate = project.targetDate {
                                PillView(text: "Target \(targetDate)", style: .warningSubtle)
                            }
                            PillView(text: "\(tasks.count) active tasks", style: .company)
                        }
                        HStack {
                            Button("Complete") { complete(project) }
                            Button("Archive") { archive(project) }
                        }
                        Divider()
                        Text("Project Task Preview")
                            .font(.headline)
                        if tasks.isEmpty {
                            EmptyStateInline(title: "No active tasks", message: "Project tasks are handled from Company Workbench.")
                        } else {
                            TaskCardList {
                                ForEach(tasks.prefix(5)) { task in
                                    TaskCardView(
                                        task: task,
                                        projectName: nil,
                                        spaceStyle: .company,
                                        spaceLabel: "Company",
                                        compact: true,
                                        onSelect: {},
                                        onComplete: { completeTask(task) },
                                        onReopen: {},
                                        onArchive: { archiveTask(task) }
                                    )
                                }
                            }
                        }
                        Spacer()
                    }
                }
            } else {
                EmptyStateCardView(title: "Select a project", message: "Project details and a short task preview appear here.", systemImage: "folder")
            }
        }
    }
}

private struct ProjectFormView: View {
    let save: (ProjectDraft) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ProjectDraft()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "New Company Project", subtitle: "Projects are company-only in v1.")
            Form {
                TextField("Name", text: $draft.name)
                TextField("Description", text: $draft.description, axis: .vertical)
                TextField("Start date (YYYY-MM-DD)", text: $draft.startDate)
                TextField("Target date (YYYY-MM-DD)", text: $draft.targetDate)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    Task {
                        await save(draft)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(AppTheme.Spacing.xl)
        .frame(width: 520)
    }
}
#endif
