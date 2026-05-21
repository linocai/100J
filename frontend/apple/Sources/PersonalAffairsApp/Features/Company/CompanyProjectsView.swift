import PersonalAffairsCore
import SwiftUI

#if os(macOS)
struct CompanyProjectsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.workbenchLayout) private var layout
    @State private var status: ProjectStatus = .active
    @State private var showingNewProject = false
    @State private var selectedProjectId: String?
    @State private var projectTasks: [TaskItem] = []
    var selection: InspectorSelection? = nil
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
                            isSelected: selectedProjectId == project.id || selection == .project(project.id),
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
            .padding(layout.pagePadding)
        }
        .sheet(isPresented: $showingNewProject) {
            ProjectFormView { draft in
                await model.createProject(draft)
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
            eyebrow: "公司",
            title: "项目",
            subtitle: "项目展示整体形状；日常任务处理仍然回到公司工作台。",
            systemImage: "folder",
            accent: AppTheme.Colors.companyAccent
        ) {
            HStack {
                Picker("状态", selection: $status) {
                    ForEach(ProjectStatus.allCases) { status in
                        Text(status.label).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                .onValueChange(of: status) { newValue in
                    Task { await model.reloadProjects(status: newValue) }
                }

                Button {
                    showingNewProject = true
                } label: {
                    Label("新建项目", systemImage: "plus")
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
        projectTasks = await model.loadProjectTasks(projectId: projectId)
    }

    private func complete(_ project: Project) {
        Task { await model.completeProject(project) }
    }

    private func archive(_ project: Project) {
        Task { await model.archiveProject(project) }
    }

    private func completeTask(_ task: TaskItem) {
        Task {
            await model.completeTask(task)
            await loadProjectTasks(task.projectId)
        }
    }

    private func archiveTask(_ task: TaskItem) {
        Task {
            await model.archiveTask(task)
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
                PillView(text: project.status.label, style: project.status.pillStyle)
                if let targetDate = project.targetDate {
                    PillView(text: "目标 \(targetDate)", style: .warningSubtle)
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
                                Text(project.description ?? "项目详情")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            PillView(text: project.status.label, style: project.status.pillStyle)
                        }
                        HStack(spacing: 6) {
                            if let startDate = project.startDate {
                                PillView(text: "开始 \(startDate)", style: .neutralSubtle)
                            }
                            if let targetDate = project.targetDate {
                                PillView(text: "目标 \(targetDate)", style: .warningSubtle)
                            }
                            PillView(text: "\(tasks.count) 个进行中任务", style: .company)
                        }
                        HStack {
                            Button("完成") { complete(project) }
                            Button("归档") { archive(project) }
                        }
                        Divider()
                        Text("项目任务预览")
                            .font(.headline)
                        if tasks.isEmpty {
                            EmptyStateInline(title: "暂无进行中任务", message: "项目任务从公司工作台统一处理。")
                        } else {
                            TaskCardList {
                                ForEach(tasks.prefix(5)) { task in
                                    TaskCardView(
                                        task: task,
                                        projectName: nil,
                                        spaceStyle: .company,
                                        spaceLabel: "公司",
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
                EmptyStateCardView(title: "选择一个项目", message: "这里会显示项目详情和任务预览。", systemImage: "folder")
            }
        }
    }
}

private struct ProjectFormView: View {
    let save: (ProjectDraft) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ProjectDraft()

    var body: some View {
        EditorSheetView(
            title: "新建公司项目",
            subtitle: "v1 中项目只属于公司空间。",
            isActionDisabled: draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            cancel: { dismiss() },
            action: {
                Task {
                    await save(draft)
                    dismiss()
                }
            }
        ) {
            Form {
                TextField("名称", text: $draft.name)
                TextField("描述", text: $draft.description, axis: .vertical)
                Toggle("设置开始日期", isOn: $draft.hasStartDate)
                if draft.hasStartDate {
                    DatePicker("开始日期", selection: $draft.startDate, displayedComponents: .date)
                }
                Toggle("设置目标日期", isOn: $draft.hasTargetDate)
                if draft.hasTargetDate {
                    DatePicker("目标日期", selection: $draft.targetDate, displayedComponents: .date)
                }
            }
        }
    }
}
#endif
