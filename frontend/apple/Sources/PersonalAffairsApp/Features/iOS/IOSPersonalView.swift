#if os(iOS)
import PersonalAffairsCore
import SwiftUI

struct IOSPersonalView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case tasks = "Tasks"
        case notes = "Notes"
        var id: String { rawValue }
    }

    @State private var segment: Segment = .tasks

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                IOSScreenHeader(title: "Personal", subtitle: "Tasks and notes only. Personal projects do not exist in v1.")
                Picker("Personal view", selection: $segment) {
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
            .navigationTitle("Personal")
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
            Picker("Status", selection: $status) {
                ForEach(TaskStatus.allCases) { status in
                    Text(status.label).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: status) { newValue in
                Task { await model.reloadPersonalTasks(status: newValue) }
            }

            if model.personalTasks.isEmpty {
                IOSUnavailableView(title: "No Tasks", systemImage: "checklist", message: "Flexible personal work will appear here.")
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
                                Label("Archive", systemImage: "archivebox")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await toggleDone(task) }
                            } label: {
                                Label(task.status == .done ? "Reopen" : "Done", systemImage: task.status == .done ? "arrow.uturn.left" : "checkmark")
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
            IOSTaskForm(title: "New Personal Task", projects: [], allowsProject: false) { draft in
                guard let space = model.personalSpace else { return }
                await model.run {
                    _ = try await model.taskRepository.create(
                        TaskCreateRequest(
                            spaceId: space.id,
                            title: draft.title,
                            description: draft.description.trimmedOrNil,
                            priority: draft.priority,
                            dueDate: draft.dueDate.trimmedOrNil
                        )
                    )
                    model.personalTasks = try await model.taskRepository.list(spaceId: space.id, status: status)
                }
            }
        }
        .sheet(item: $editingTask) { task in
            IOSTaskForm(
                title: "Edit Personal Task",
                projects: [],
                allowsProject: false,
                initialDraft: TaskDraft(
                    title: task.title,
                    description: task.description ?? "",
                    priority: task.priority,
                    dueDate: task.dueDate ?? "",
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
                            dueDate: draft.dueDate.trimmedOrNil
                        )
                    )
                    guard let space = model.personalSpace else { return }
                    model.personalTasks = try await model.taskRepository.list(spaceId: space.id, status: status)
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
            model.personalTasks = try await model.taskRepository.list(spaceId: space.id, status: status)
        }
    }

    private func archive(_ task: TaskItem) async {
        await model.run {
            _ = try await model.taskRepository.archive(id: task.id)
            guard let space = model.personalSpace else { return }
            model.personalTasks = try await model.taskRepository.list(spaceId: space.id, status: status)
        }
    }
}

private struct IOSPersonalNotesList: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingNewNote = false
    @State private var editingNote: Note?

    var body: some View {
        List {
            if model.notes.isEmpty {
                IOSUnavailableView(title: "No Notes", systemImage: "note.text", message: "Personal ideas and memos will appear here.")
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
                                Label("Archive", systemImage: "archivebox")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await convert(note) }
                            } label: {
                                Label("Task", systemImage: "arrow.triangle.branch")
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
