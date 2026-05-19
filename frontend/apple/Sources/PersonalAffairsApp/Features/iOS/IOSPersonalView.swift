#if os(iOS)
import PersonalAffairsCore
import SwiftUI

struct IOSPersonalView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case tasks = "待办"
        case notes = "备忘"
        var id: String { rawValue }
    }

    @State private var segment: Segment = .tasks

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                IOSScreenHeader(title: "个人", subtitle: "这里只放待办和备忘；v1 中个人没有项目。")
                Picker("个人视图", selection: $segment) {
                    ForEach(Segment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch segment {
                case .tasks:
                    IOSPersonalTasksList()
                case .notes:
                    IOSPersonalNotesList()
                }
            }
            .navigationTitle("个人")
            .navigationBarTitleDisplayMode(.inline)
            .overlay { IOSLoadingOverlay() }
            .iosErrorAlert()
        }
    }
}

private struct IOSPersonalTasksList: View {
    @EnvironmentObject private var model: AppModel
    @State private var status: TaskStatus = .active
    @State private var showingNewTask = false
    @State private var editingTask: TaskItem?

    var body: some View {
        List {
            Picker("状态", selection: $status) {
                ForEach(TaskStatus.allCases) { status in
                    Text(status.label).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: status) { newValue in
                Task { await model.reloadPersonalTasks(status: newValue) }
            }

            if model.personalTasks.isEmpty {
                IOSUnavailableView(title: "暂无待办", systemImage: "checklist", message: "个人弹性事项会显示在这里。")
            } else {
                ForEach(model.personalTasks) { task in
                    IOSTaskRow(task: task, projectName: nil)
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
            IOSTaskForm(title: "新建个人待办", projects: [], allowsProject: false) { draft in
                guard let space = model.personalSpace else { return }
                await model.run {
                    _ = try await model.taskRepository.create(
                        TaskCreateRequest(
                            spaceId: space.id,
                            title: draft.title,
                            description: draft.description.trimmedOrNil,
                            priority: draft.priority,
                            dueDate: draft.dueDateString
                        )
                    )
                    model.personalTasks = try await model.taskRepository.list(query: personalQuery(spaceId: space.id))
                }
            }
        }
        .sheet(item: $editingTask) { task in
            IOSTaskForm(
                title: "编辑个人待办",
                projects: [],
                allowsProject: false,
                initialDraft: TaskDraft(
                    title: task.title,
                    description: task.description ?? "",
                    priority: task.priority,
                    dueDateString: task.dueDate,
                    projectId: nil
                )
            ) { draft in
                await model.run {
                    _ = try await model.taskRepository.update(
                        id: task.id,
                        request: TaskUpdateRequest(
                            title: draft.title,
                            description: draft.description.trimmedOrNil,
                            priority: draft.priority,
                            dueDate: draft.dueDateString
                        )
                    )
                    guard let space = model.personalSpace else { return }
                    model.personalTasks = try await model.taskRepository.list(query: personalQuery(spaceId: space.id))
                }
            }
        }
        .refreshable {
            await model.reloadPersonalTasks(status: status)
        }
        .task {
            await model.reloadPersonalTasks(status: status)
        }
    }

    private func toggleDone(_ task: TaskItem) async {
        await model.run {
            if task.status == .done {
                _ = try await model.taskRepository.reopen(id: task.id)
            } else {
                _ = try await model.taskRepository.complete(id: task.id)
            }
            guard let space = model.personalSpace else { return }
            model.personalTasks = try await model.taskRepository.list(query: personalQuery(spaceId: space.id))
        }
    }

    private func archive(_ task: TaskItem) async {
        await model.run {
            _ = try await model.taskRepository.archive(id: task.id)
            guard let space = model.personalSpace else { return }
            model.personalTasks = try await model.taskRepository.list(query: personalQuery(spaceId: space.id))
        }
    }

    private func personalQuery(spaceId: String) -> TaskListQuery {
        PersonalTasksViewState.query(personalSpaceId: spaceId, status: status)
    }
}

private struct IOSPersonalNotesList: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingNewNote = false
    @State private var editingNote: Note?

    var body: some View {
        List {
            if model.notes.isEmpty {
                IOSUnavailableView(title: "暂无备忘", systemImage: "note.text", message: "个人灵感和备忘会显示在这里。")
            } else {
                ForEach(model.notes) { note in
                    IOSNoteRow(note: note)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingNote = note
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await archive(note) }
                            } label: {
                                Label("归档", systemImage: "archivebox")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await convert(note) }
                            } label: {
                                Label("转待办", systemImage: "arrow.triangle.branch")
                            }
                            .tint(.green)
                        }
                }
            }
        }
        .toolbar {
            Button {
                showingNewNote = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingNewNote) {
            IOSNoteForm { draft in
                guard let space = model.personalSpace else { return }
                await model.run {
                    _ = try await model.noteRepository.create(
                        NoteCreateRequest(spaceId: space.id, title: draft.title.trimmedOrNil, body: draft.body, type: draft.type)
                    )
                    model.notes = try await model.noteRepository.list(status: .active)
                }
            }
        }
        .sheet(item: $editingNote) { note in
            IOSNoteForm(
                initialDraft: NoteDraft(title: note.title ?? "", body: note.body, type: note.type)
            ) { draft in
                await model.run {
                    _ = try await model.noteRepository.update(
                        id: note.id,
                        request: NoteUpdateRequest(
                            title: draft.title.trimmedOrNil,
                            body: draft.body,
                            type: draft.type
                        )
                    )
                    model.notes = try await model.noteRepository.list(status: .active)
                }
            }
        }
        .refreshable {
            await model.reloadNotes(status: .active)
        }
        .task {
            await model.reloadNotes(status: .active)
        }
    }

    private func archive(_ note: Note) async {
        await model.run {
            _ = try await model.noteRepository.archive(id: note.id)
            model.notes = try await model.noteRepository.list(status: .active)
        }
    }

    private func convert(_ note: Note) async {
        await model.run {
            let title = note.title?.trimmedOrNil ?? String(note.body.prefix(48))
            _ = try await model.noteRepository.convertToTask(noteId: note.id, request: ConvertNoteToTaskRequest(title: title))
            try await model.loadAllData()
        }
    }
}
#endif
