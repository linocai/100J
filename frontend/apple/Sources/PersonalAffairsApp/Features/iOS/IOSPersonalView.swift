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
            .onValueChange(of: status) { newValue in
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
            IOSTaskForm(title: "新建个人待办", projects: [], allowsProject: false) { draft in
                await model.createPersonalTask(draft)
            }
        }
        .sheet(item: $editingTask) { task in
            IOSTaskForm(
                title: "编辑个人待办",
                projects: [],
                allowsProject: false,
                initialDraft: TaskDraft(task)
            ) { draft in
                await model.updateTask(id: task.id, draft: draft, includesProject: false)
            }
        }
        .refreshable {
            await model.reloadPersonalTasks(status: status)
        }
        .task {
            await model.reloadPersonalTasks(status: status)
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
                                Task { await model.archiveNote(note) }
                            } label: {
                                Label("归档", systemImage: "archivebox")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await model.convertNoteToTask(note) }
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
                await model.createNote(draft)
            }
        }
        .sheet(item: $editingNote) { note in
            IOSNoteForm(initialDraft: NoteDraft(note)) { draft in
                await model.updateNote(id: note.id, draft: draft)
            }
        }
        .refreshable {
            await model.reloadNotes(status: .active)
        }
        .task {
            await model.reloadNotes(status: .active)
        }
    }
}
#endif
