import PersonalAffairsCore
import SwiftUI

struct PersonalTasksView: View {
    @EnvironmentObject private var model: AppModel
    @State private var status: TaskStatus = .active
    @State private var search = ""
    @State private var showingNewTask = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.personalTasks.isEmpty {
                EmptyStateView(title: "No personal tasks", message: "Flexible personal work will appear here.")
            } else {
                List(model.personalTasks) { task in
                    TaskRow(
                        task: task,
                        projectName: nil,
                        complete: { complete(task) },
                        reopen: { reopen(task) },
                        archive: { archive(task) }
                    )
                }
            }
        }
        .sheet(isPresented: $showingNewTask) {
            TaskFormView(title: "New Personal Task", projects: [], allowsProject: false) { draft in
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
                    model.personalTasks = try await model.taskRepository.list(
                        spaceId: space.id,
                        status: status,
                        search: search.trimmedOrNil
                    )
                }
            }
        }
        .task {
            await model.reloadPersonalTasks(status: status, search: search.trimmedOrNil)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            ToolbarTitle(title: "Personal Tasks", subtitle: "Flexible personal work. Due dates stay in tasks.")
            Spacer()
            Picker("Status", selection: $status) {
                ForEach(TaskStatus.allCases) { status in
                    Text(status.label).tag(status)
                }
            }
            .frame(width: 140)
            .onChange(of: status) { newValue in
                Task { await model.reloadPersonalTasks(status: newValue, search: search.trimmedOrNil) }
            }

            TextField("Search", text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                .onSubmit {
                    Task { await model.reloadPersonalTasks(status: status, search: search.trimmedOrNil) }
                }

            Button {
                showingNewTask = true
            } label: {
                Label("New Task", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func complete(_ task: TaskItem) {
        Task {
            await model.run {
                _ = try await model.taskRepository.complete(id: task.id)
                guard let space = model.personalSpace else { return }
                model.personalTasks = try await model.taskRepository.list(spaceId: space.id, status: status, search: search.trimmedOrNil)
            }
        }
    }

    private func reopen(_ task: TaskItem) {
        Task {
            await model.run {
                _ = try await model.taskRepository.reopen(id: task.id)
                guard let space = model.personalSpace else { return }
                model.personalTasks = try await model.taskRepository.list(spaceId: space.id, status: status, search: search.trimmedOrNil)
            }
        }
    }

    private func archive(_ task: TaskItem) {
        Task {
            await model.run {
                _ = try await model.taskRepository.archive(id: task.id)
                guard let space = model.personalSpace else { return }
                model.personalTasks = try await model.taskRepository.list(spaceId: space.id, status: status, search: search.trimmedOrNil)
            }
        }
    }
}

struct TaskRow: View {
    let task: TaskItem
    let projectName: String?
    let complete: () -> Void
    let reopen: () -> Void
    let archive: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: task.status == .done ? reopen : complete) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.status == .done)
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack {
                    BadgeText(text: task.priority.label, color: task.priority == .urgent ? .red : .secondary)
                    BadgeText(text: task.status.label)
                    if let dueDate = task.dueDate {
                        BadgeText(text: "Due \(dueDate)", color: .orange)
                    }
                    if let projectName {
                        BadgeText(text: projectName, color: .blue)
                    }
                    if task.source == "agent" {
                        BadgeText(text: "Agent", color: .indigo)
                    }
                }
            }
            Spacer()
            Button(action: archive) {
                Image(systemName: "archivebox")
            }
            .buttonStyle(.borderless)
            .help("Archive")
        }
        .padding(.vertical, 6)
    }
}

struct TaskDraft {
    var title = ""
    var description = ""
    var priority: TaskPriority = .medium
    var dueDate = ""
    var projectId: String?
}

struct TaskFormView: View {
    let title: String
    let projects: [Project]
    let allowsProject: Bool
    let save: (TaskDraft) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = TaskDraft()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.weight(.semibold))
            Form {
                TextField("Title", text: $draft.title)
                TextField("Description", text: $draft.description, axis: .vertical)
                Picker("Priority", selection: $draft.priority) {
                    ForEach(TaskPriority.allCases) { priority in
                        Text(priority.label).tag(priority)
                    }
                }
                TextField("Due date (YYYY-MM-DD)", text: $draft.dueDate)
                if allowsProject {
                    Picker("Project", selection: $draft.projectId) {
                        Text("No Project").tag(Optional<String>.none)
                        ForEach(projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                }
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
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 460)
    }
}
