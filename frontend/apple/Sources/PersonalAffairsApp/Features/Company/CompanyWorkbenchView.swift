import PersonalAffairsCore
import SwiftUI

struct CompanyWorkbenchView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingNewTask = false
    @State private var showingNewProject = false
    @State private var selectedProjectId: String?

    let selectTask: (TaskItem) -> Void
    let selectProject: (Project) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                SectionHeaderView(
                    eyebrow: "Company",
                    title: "Company Workbench",
                    subtitle: "Project work and no-project tasks share one command surface.",
                    systemImage: "rectangle.3.group"
                ) {
                    HStack {
                        Button {
                            showingNewProject = true
                        } label: {
                            Label("New Project", systemImage: "folder.badge.plus")
                        }
                        Button {
                            showingNewTask = true
                        } label: {
                            Label("New Task", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                ProjectOverviewStrip(
                    projects: sortedProjects,
                    tasks: model.companyTasks,
                    selectedProjectId: selectedProjectId,
                    select: { project in
                        selectedProjectId = project.id
                        selectProject(project)
                    }
                )

                SurfaceView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Task Board")
                                    .font(.headline.weight(.semibold))
                                Text("No Project Inbox is a company task grouping, not a fourth task status.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            PillView(text: "Active / Done / Archived only", style: .neutralSubtle)
                        }

                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                                CompanyTaskLane(
                                    title: "No Project Inbox",
                                    subtitle: "project_id = nil",
                                    tasks: sortedForFocus(model.noProjectCompanyTasks),
                                    projectName: nil,
                                    selectTask: selectTask
                                )
                                ForEach(sortedProjects) { project in
                                    CompanyTaskLane(
                                        title: project.name,
                                        subtitle: project.targetDate.map { "Target \($0)" } ?? "Project tasks",
                                        tasks: sortedForFocus(projectTasks(project.id)),
                                        projectName: project.name,
                                        selectTask: selectTask
                                    )
                                }
                            }
                            .padding(.bottom, AppTheme.Spacing.xs)
                        }
                    }
                }
            }
            .padding(AppTheme.Spacing.xl)
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
        .sheet(isPresented: $showingNewProject) {
            WorkbenchProjectFormView { draft in
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
            await model.run {
                try await model.loadAllData()
            }
        }
    }

    private var sortedProjects: [Project] {
        model.projects.sorted { lhs, rhs in
            if lhs.status != rhs.status {
                return lhs.status == .active
            }
            let lhsDate = parsedDateOnly(lhs.targetDate)
            let rhsDate = parsedDateOnly(rhs.targetDate)
            switch (lhsDate, rhsDate) {
            case let (left?, right?) where left != right:
                return left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.updatedAt > rhs.updatedAt
            }
        }
    }

    private func projectTasks(_ projectId: String) -> [TaskItem] {
        model.companyTasks.filter { $0.projectId == projectId && $0.status == .active }
    }
}

private struct ProjectOverviewStrip: View {
    let projects: [Project]
    let tasks: [TaskItem]
    let selectedProjectId: String?
    let select: (Project) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Text("Project Overview")
                    .font(.headline.weight(.semibold))
                Spacer()
                PillView(text: "\(projects.count) active projects", style: .company)
            }

            if projects.isEmpty {
                EmptyStateCardView(
                    title: "No company projects yet",
                    message: "Create a project for larger company work, or keep small tasks in No Project Inbox.",
                    systemImage: "folder"
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: AppTheme.Spacing.md)], spacing: AppTheme.Spacing.md) {
                    ForEach(projects.prefix(6)) { project in
                        ProjectCardView(
                            project: project,
                            activeTaskCount: activeCount(project.id),
                            completedTaskCount: completedCount(project.id),
                            isSelected: selectedProjectId == project.id,
                            onSelect: { select(project) }
                        )
                    }
                }
            }
        }
    }

    private func activeCount(_ projectId: String) -> Int {
        tasks.filter { $0.projectId == projectId && $0.status == .active }.count
    }

    private func completedCount(_ projectId: String) -> Int {
        tasks.filter { $0.projectId == projectId && $0.status == .done }.count
    }
}

private struct CompanyTaskLane: View {
    @EnvironmentObject private var model: AppModel
    let title: String
    let subtitle: String
    let tasks: [TaskItem]
    let projectName: String?
    let selectTask: (TaskItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(tasks.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.companyAccent)
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(AppTheme.Colors.companyAccent.opacity(0.12))
                    .clipShape(Capsule())
            }

            if tasks.isEmpty {
                EmptyStateInline(
                    title: "Empty",
                    message: projectName == nil ? "No loose company tasks." : "No active tasks in this project."
                )
            } else {
                TaskCardList {
                    ForEach(tasks) { task in
                        TaskCardView(
                            task: task,
                            projectName: projectName,
                            spaceStyle: .company,
                            spaceLabel: "Company",
                            compact: true,
                            onSelect: { selectTask(task) },
                            onComplete: { mutateTask(.complete, task) },
                            onReopen: { mutateTask(.reopen, task) },
                            onArchive: { mutateTask(.archive, task) }
                        )
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(width: 284)
        .frame(minHeight: 430, alignment: .topLeading)
        .padding(AppTheme.Spacing.md)
        .background(Color.white.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .stroke(Color.white.opacity(0.38), lineWidth: 1)
        }
    }

    private enum Mutation {
        case complete
        case reopen
        case archive
    }

    private func mutateTask(_ mutation: Mutation, _ task: TaskItem) {
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
}

private struct WorkbenchProjectFormView: View {
    let save: (ProjectDraft) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ProjectDraft()

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            SectionHeaderView(
                eyebrow: "Company",
                title: "New Project",
                subtitle: "Projects are company-only in 100J v1."
            )
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
