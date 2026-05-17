import PersonalAffairsCore
import SwiftUI

struct CompanyProjectsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var status: ProjectStatus = .active
    @State private var showingNewProject = false
    @State private var selectedProjectId: String?
    @State private var projectTasks: [TaskItem] = []

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                header
                Divider()
                List(selection: $selectedProjectId) {
                    ForEach(model.projects) { project in
                        ProjectRow(project: project)
                            .tag(Optional(project.id))
                    }
                }
                .onChange(of: selectedProjectId) { projectId in
                    Task { await loadProjectTasks(projectId) }
                }
            }
            .frame(minWidth: 420)

            ProjectDetailView(
                project: selectedProject,
                tasks: projectTasks,
                complete: { project in complete(project) },
                archive: { project in archive(project) }
            )
            .frame(minWidth: 420)
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
        HStack(spacing: 14) {
            ToolbarTitle(title: "Company Projects", subtitle: "Projects are company-only in v1.")
            Spacer()
            Picker("Status", selection: $status) {
                ForEach(ProjectStatus.allCases) { status in
                    Text(status.label).tag(status)
                }
            }
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
        .padding()
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

    var body: some View {
        Group {
            if let project {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        ToolbarTitle(title: project.name, subtitle: project.description ?? "Project detail")
                        Spacer()
                        Button("Complete") { complete(project) }
                        Button("Archive") { archive(project) }
                    }
                    Divider()
                    Text("Active Tasks")
                        .font(.headline)
                    if tasks.isEmpty {
                        EmptyStateView(title: "No active tasks", message: "Project tasks will appear here.")
                    } else {
                        List(tasks) { task in
                            TaskRow(task: task, projectName: nil, complete: {}, reopen: {}, archive: {})
                        }
                    }
                    Spacer()
                }
                .padding()
            } else {
                EmptyStateView(title: "Select a project", message: "Project tasks and details appear here.")
            }
        }
    }
}

private struct ProjectDraft {
    var name = ""
    var description = ""
    var startDate = ""
    var targetDate = ""
}

private struct ProjectFormView: View {
    let save: (ProjectDraft) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ProjectDraft()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Company Project")
                .font(.title2.weight(.semibold))
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
        .padding()
        .frame(width: 460)
    }
}
