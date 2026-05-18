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
                Section("待办") {
                    TextField("标题", text: $draft.title)
                    TextField("描述", text: $draft.description, axis: .vertical)
                    Picker("优先级", selection: $draft.priority) {
                        ForEach(TaskPriority.allCases) { priority in
                            Text(priority.label).tag(priority)
                        }
                    }
                    Toggle("设置截止日期", isOn: $draft.hasDueDate)
                    if draft.hasDueDate {
                        DatePicker("截止日期", selection: $draft.dueDate, displayedComponents: .date)
                    }
                }
                if allowsProject {
                    Section("公司项目") {
                        Picker("项目", selection: $draft.projectId) {
                            Text("无项目").tag(Optional<String>.none)
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
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
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
                TextField("标题", text: $draft.title)
                Picker("类型", selection: $draft.type) {
                    ForEach(NoteType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                TextField("正文", text: $draft.body, axis: .vertical)
                    .lineLimit(6...10)
            }
            .navigationTitle("新建备忘")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
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
            .navigationTitle("新建项目")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
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
