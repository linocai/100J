#if os(iOS)
import PersonalAffairsCore
import SwiftUI

struct IOSPlanScreen: View {
    enum Segment: String, CaseIterable, Identifiable {
        case personal
        case company
        case projects
        case notes

        var id: String { rawValue }

        var title: String {
            switch self {
            case .personal: return "个人"
            case .company: return "公司"
            case .projects: return "项目"
            case .notes: return "笔记"
            }
        }

        /// 给 Universal Composer 的预填提示，让 Composer 内联默认 intent。
        var composerHint: String {
            switch self {
            case .personal: return "个人 "
            case .company: return "公司 "
            case .projects: return "新项目 "
            case .notes: return "灵感 "
            }
        }
    }

    @EnvironmentObject private var model: AppModel
    @State private var segment: Segment = .personal
    @State private var showingNewTask = false
    @State private var showingNewNote = false
    @State private var showingNewProject = false
    @State private var editingTask: TaskItem?
    @State private var editingNote: Note?
    @State private var editingProject: Project?

    var body: some View {
        List {
            Section {
                Picker("Plan", selection: $segment) {
                    ForEach(Segment.allCases) { segment in
                        Text(segment.title).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
            }

            content
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $model.search, placement: .navigationBarDrawer(displayMode: .always))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.universalComposerViewModel.open(prefill: segment.composerHint)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("新建")
            }
        }
        .sheet(isPresented: $showingNewTask) {
            IOSTaskForm(title: newTaskTitle, projects: model.projects, allowsProject: segment == .company) { draft in
                if segment == .company {
                    await model.createCompanyTask(draft)
                } else {
                    await model.createPersonalTask(draft)
                }
            }
        }
        .sheet(isPresented: $showingNewNote) {
            IOSNoteForm { draft in
                await model.createNote(draft)
            }
        }
        .sheet(isPresented: $showingNewProject) {
            IOSProjectForm { draft in
                await model.createProject(draft)
            }
        }
        .sheet(item: $editingTask) { task in
            IOSTaskForm(
                title: task.spaceId == model.personalSpace?.id ? "编辑个人待办" : "编辑公司待办",
                projects: model.projects,
                allowsProject: task.spaceId == model.companySpace?.id,
                initialDraft: TaskDraft(task)
            ) { draft in
                await model.updateTask(id: task.id, draft: draft, includesProject: task.spaceId == model.companySpace?.id)
            }
        }
        .sheet(item: $editingNote) { note in
            IOSNoteForm(initialDraft: NoteDraft(note)) { draft in
                await model.updateNote(id: note.id, draft: draft)
            }
        }
        .sheet(item: $editingProject) { project in
            IOSProjectForm(initialDraft: ProjectDraft(project)) { draft in
                await model.updateProject(id: project.id, draft: draft)
            }
        }
        .refreshable { await model.refreshAll() }
        .overlay { IOSLoadingOverlay() }
        .iosErrorAlert()
        .task {
            await model.refreshAll()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch segment {
        case .personal:
            taskSection(title: "个人待办", tasks: filteredPersonalTasks, projectNames: false)
        case .company:
            taskSection(title: "公司待办", tasks: filteredCompanyTasks, projectNames: true)
        case .projects:
            projectSection
        case .notes:
            noteSection
        }
    }

    private func taskSection(title: String, tasks: [TaskItem], projectNames: Bool) -> some View {
        Section(title) {
            if tasks.isEmpty {
                IOSUnavailableView(title: "暂无\(title)", systemImage: "checklist", message: "右上角加号或 ⌘K 可快速创建。")
            } else {
                ForEach(tasks) { task in
                    IOSTaskRow(task: task, projectName: projectNames ? model.projectName(for: task.projectId) : nil)
                        .contentShape(Rectangle())
                        .onTapGesture { editingTask = task }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await model.toggleTaskDone(task) }
                            } label: {
                                Label(task.status == .done ? "重新打开" : "完成", systemImage: task.status == .done ? "arrow.uturn.left" : "checkmark")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await model.archiveTask(task) }
                            } label: {
                                Label("归档", systemImage: "archivebox")
                            }
                        }
                }
            }
        }
    }

    private var projectSection: some View {
        Section("项目") {
            if filteredProjects.isEmpty {
                IOSUnavailableView(title: "暂无项目", systemImage: "folder", message: "较大的公司事项可以沉淀为项目。")
            } else {
                ForEach(filteredProjects) { project in
                    IOSProjectRow(project: project)
                        .contentShape(Rectangle())
                        .onTapGesture { editingProject = project }
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
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await model.archiveProject(project) }
                            } label: {
                                Label("归档", systemImage: "archivebox")
                            }
                        }
                }
            }
        }
    }

    private var noteSection: some View {
        Section("笔记") {
            if filteredNotes.isEmpty {
                IOSUnavailableView(title: "暂无笔记", systemImage: "note.text", message: "灵感和备忘先放在这里。")
            } else {
                ForEach(filteredNotes) { note in
                    IOSNoteRow(note: note)
                        .contentShape(Rectangle())
                        .onTapGesture { editingNote = note }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await model.convertNoteToTask(note) }
                            } label: {
                                Label("转待办", systemImage: "arrow.triangle.branch")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await model.archiveNote(note) }
                            } label: {
                                Label("归档", systemImage: "archivebox")
                            }
                        }
                }
            }
        }
    }

    private var filteredPersonalTasks: [TaskItem] {
        filter(model.planViewModel.personalItems) { $0.matchesSearch($1, projectName: nil) }
    }

    private var filteredCompanyTasks: [TaskItem] {
        filter(model.planViewModel.companyItems) { $0.matchesSearch($1, projectName: model.projectName(for: $0.projectId)) }
    }

    private var filteredProjects: [Project] {
        filter(model.planViewModel.projectItems) { project, term in
            project.name.localizedCaseInsensitiveContains(term)
                || (project.description?.localizedCaseInsensitiveContains(term) ?? false)
        }
    }

    private var filteredNotes: [Note] {
        filter(model.planViewModel.noteItems) { note, term in
            (note.title?.localizedCaseInsensitiveContains(term) ?? false)
                || note.body.localizedCaseInsensitiveContains(term)
                || note.type.label.localizedCaseInsensitiveContains(term)
        }
    }

    private func filter<Item>(_ items: [Item], matches: (Item, String) -> Bool) -> [Item] {
        guard let term = model.search.trimmedOrNil else { return items }
        return items.filter { matches($0, term) }
    }

    private func openCreateSheet() {
        switch segment {
        case .personal, .company:
            showingNewTask = true
        case .projects:
            showingNewProject = true
        case .notes:
            showingNewNote = true
        }
    }

    private var newTaskTitle: String {
        segment == .company ? "新建公司待办" : "新建个人待办"
    }
}
#endif
