import PersonalAffairsCore
import SwiftUI

struct CompanyWorkbenchView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.workbenchLayout) private var layout
    @State private var showingNewTask = false
    @State private var showingNewProject = false
    @State private var selectedProjectId: String?
    @State private var search = ""
    @FocusState private var isSearchFocused: Bool

    var selection: InspectorSelection? = nil
    let selectTask: (TaskItem) -> Void
    let selectProject: (Project) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                SectionHeaderView(
                    eyebrow: "公司",
                    title: "公司工作台",
                    subtitle: "项目任务和无项目小任务都在同一个公司界面处理。",
                    systemImage: "rectangle.3.group"
                ) {
                    HStack {
                        Button {
                            showingNewProject = true
                        } label: {
                            Label("新建项目", systemImage: "folder.badge.plus")
                        }
                        Button {
                            showingNewTask = true
                        } label: {
                            Label("新建待办", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                ProjectOverviewStrip(
                    projects: visibleProjects,
                    tasks: visibleCompanyTasks,
                    selectedProjectId: selectedProjectId,
                    showMoreProjects: { model.selectedSection = .companyProjects },
                    select: { project in
                        selectedProjectId = project.id
                        selectProject(project)
                    }
                )

                SurfaceView(style: .elevated) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("任务看板")
                                    .font(.headline.weight(.semibold))
                                Text("无项目收件箱是公司任务分组，不是第四种任务状态。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            PillView(text: "无项目 = 公司任务分组，不是状态", style: .warningSubtle)
                        }
                        TextField("搜索公司任务或项目", text: $search)
                            .textFieldStyle(.roundedBorder)
                            .focused($isSearchFocused)
                            .frame(maxWidth: min(360, max(260, layout.centerWidth * 0.32)))

                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                                ForEach(workbenchLanes) { lane in
                                    CompanyTaskLane(
                                        title: lane.title,
                                        subtitle: lane.subtitle,
                                        tasks: lane.tasks,
                                        projectName: lane.projectName,
                                        isInbox: lane.isInbox,
                                        isSelectedProject: isSelected(lane),
                                        selection: selection,
                                        selectTask: selectTask
                                    )
                                }
                            }
                            .padding(.bottom, AppTheme.Spacing.md)
                        }
                    }
                }
            }
            .padding(layout.pagePadding)
        }
        .sheet(isPresented: $showingNewTask) {
            TaskFormView(title: "新建公司待办", projects: model.projects, allowsProject: true) { draft in
                await model.createCompanyTask(draft)
            }
        }
        .sheet(isPresented: $showingNewProject) {
            WorkbenchProjectFormView { draft in
                await model.createProject(draft)
            }
        }
        .task {
            await model.run {
                try await model.loadAllData()
            }
        }
        .background(searchShortcut)
    }

    private var sortedProjects: [Project] {
        CompanyWorkbenchViewState.sortedProjects(model.projects)
    }

    private var workbenchLanes: [CompanyTaskLaneState] {
        CompanyWorkbenchViewState.lanes(projects: visibleProjects, tasks: visibleCompanyTasks)
    }

    private var visibleProjects: [Project] {
        guard let term = searchTerm else { return sortedProjects }
        return sortedProjects.filter { project in
            project.name.localizedCaseInsensitiveContains(term)
                || (project.description?.localizedCaseInsensitiveContains(term) ?? false)
                || model.companyTasks.contains { task in
                    task.projectId == project.id && matches(task, term: term)
                }
        }
    }

    private var visibleCompanyTasks: [TaskItem] {
        guard let term = searchTerm else { return model.companyTasks }
        return model.companyTasks.filter { task in matches(task, term: term) }
    }

    private var searchTerm: String? {
        search.trimmedOrNil
    }

    private func matches(_ task: TaskItem, term: String) -> Bool {
        task.title.localizedCaseInsensitiveContains(term)
            || (task.description?.localizedCaseInsensitiveContains(term) ?? false)
            || (model.projectName(for: task.projectId)?.localizedCaseInsensitiveContains(term) ?? false)
    }

    private func isSelected(_ lane: CompanyTaskLaneState) -> Bool {
        if let projectId = lane.projectId {
            return selectedProjectId == projectId || selection == .project(projectId)
        }
        return selectedProjectId == nil
    }

    @ViewBuilder
    private var searchShortcut: some View {
        #if os(macOS)
        Button("聚焦搜索") {
            isSearchFocused = true
        }
        .keyboardShortcut("f", modifiers: .command)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
        #endif
    }
}

private struct ProjectOverviewStrip: View {
    let projects: [Project]
    let tasks: [TaskItem]
    let selectedProjectId: String?
    let showMoreProjects: () -> Void
    let select: (Project) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Text("项目概览")
                    .font(.headline.weight(.semibold))
                Spacer()
                PillView(text: "\(projects.count) 个进行中项目", style: .company)
                if projects.count > 6 {
                    Button(action: showMoreProjects) {
                        Label("更多", systemImage: "ellipsis.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("查看全部项目")
                }
            }

            if projects.isEmpty {
                EmptyStateCardView(
                    title: "暂无公司项目",
                    message: "较大的公司事项可以建项目，小任务可以留在无项目收件箱。",
                    systemImage: "folder"
                )
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                    ForEach(projects) { project in
                        ProjectCardView(
                            project: project,
                            activeTaskCount: activeCount(project.id),
                            completedTaskCount: completedCount(project.id),
                            isSelected: selectedProjectId == project.id,
                            onSelect: { select(project) }
                        )
                        .frame(width: 260)
                    }
                    }
                    .padding(.bottom, AppTheme.Spacing.xs)
                }
            }
        }
    }

    private func activeCount(_ projectId: String) -> Int {
        CompanyWorkbenchViewState.activeCount(projectId: projectId, tasks: tasks)
    }

    private func completedCount(_ projectId: String) -> Int {
        CompanyWorkbenchViewState.completedCount(projectId: projectId, tasks: tasks)
    }
}

private struct CompanyTaskLane: View {
    @EnvironmentObject private var model: AppModel
    let title: String
    let subtitle: String
    let tasks: [TaskItem]
    let projectName: String?
    let isInbox: Bool
    let isSelectedProject: Bool
    let selection: InspectorSelection?
    let selectTask: (TaskItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: isInbox ? "tray" : "folder")
                            .foregroundStyle(accent)
                        Text(title)
                            .font(.callout.weight(.semibold))
                            .lineLimit(2)
                    }
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(tasks.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(accent.opacity(0.12))
                    .clipShape(Capsule())
            }

            if tasks.isEmpty {
                EmptyStateInline(
                    title: "暂无任务",
                    message: projectName == nil ? "没有无项目公司任务。" : "Add task to this project."
                )
            } else {
                TaskCardList {
                    ForEach(tasks) { task in
                        TaskCardView(
                            task: task,
                            projectName: projectName,
                            spaceStyle: .company,
                            spaceLabel: "公司",
                            isSelected: selection == .task(task.id),
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
        .frame(width: 312)
        .frame(minHeight: 430, alignment: .topLeading)
        .padding(AppTheme.Spacing.md)
        .background(laneFill)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .stroke(isSelectedProject ? accent.opacity(0.36) : AppTheme.Colors.hairline, lineWidth: 1)
        }
    }

    private var accent: Color {
        isInbox ? AppTheme.Colors.warningAccent : AppTheme.Colors.companyAccent
    }

    private var laneFill: Color {
        if isSelectedProject {
            return accent.opacity(0.12)
        }
        return isInbox ? AppTheme.Colors.warningAccent.opacity(0.08) : AppTheme.Colors.surfaceTinted
    }

    private enum Mutation {
        case complete
        case reopen
        case archive
    }

    private func mutateTask(_ mutation: Mutation, _ task: TaskItem) {
        Task {
            switch mutation {
            case .complete: await model.completeTask(task)
            case .reopen: await model.reopenTask(task)
            case .archive: await model.archiveTask(task)
            }
        }
    }
}

private struct WorkbenchProjectFormView: View {
    let save: (ProjectDraft) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ProjectDraft()

    var body: some View {
        EditorSheetView(
            title: "新建项目",
            subtitle: "100J v1 中项目只属于公司空间。",
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
