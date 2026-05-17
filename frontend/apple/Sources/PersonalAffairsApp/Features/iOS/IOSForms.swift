#if os(iOS)
import PersonalAffairsCore
import SwiftUI

struct IOSTaskForm: View {
    let title: String
    let projects: [Project]
    let allowsProject: Bool
    let save: (TaskDraft) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: TaskDraft

    init(
        title: String,
        projects: [Project],
        allowsProject: Bool,
        initialDraft: TaskDraft = TaskDraft(),
        save: @escaping (TaskDraft) async -> Void
    ) {
        self.title = title
        self.projects = projects
        self.allowsProject = allowsProject
        self.save = save
        self._draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $draft.title)
                    TextField("Description", text: $draft.description, axis: .vertical)
                    Picker("Priority", selection: $draft.priority) {
                        ForEach(TaskPriority.allCases) { priority in
                            Text(priority.label).tag(priority)
                        }
                    }
                    TextField("Due date (YYYY-MM-DD)", text: $draft.dueDate)
                }
                if allowsProject {
                    Section("Company Project") {
                        Picker("Project", selection: $draft.projectId) {
                            Text("No Project").tag(Optional<String>.none)
                            ForEach(projects) { project in
                                Text(project.name).tag(Optional(project.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await save(draft)
                            dismiss()
                        }
                    }
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct IOSNoteForm: View {
    let save: (NoteDraft) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: NoteDraft

    init(initialDraft: NoteDraft = NoteDraft(), save: @escaping (NoteDraft) async -> Void) {
        self.save = save
        self._draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $draft.title)
                Picker("Type", selection: $draft.type) {
                    ForEach(NoteType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                TextField("Body", text: $draft.body, axis: .vertical)
                    .lineLimit(6...10)
            }
            .navigationTitle("New Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await save(draft)
                            dismiss()
                        }
                    }
                    .disabled(draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct IOSProjectForm: View {
    let save: (ProjectDraft) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProjectDraft

    init(initialDraft: ProjectDraft = ProjectDraft(), save: @escaping (ProjectDraft) async -> Void) {
        self.save = save
        self._draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $draft.name)
                TextField("Description", text: $draft.description, axis: .vertical)
                TextField("Start date (YYYY-MM-DD)", text: $draft.startDate)
                TextField("Target date (YYYY-MM-DD)", text: $draft.targetDate)
            }
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await save(draft)
                            dismiss()
                        }
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
#endif
