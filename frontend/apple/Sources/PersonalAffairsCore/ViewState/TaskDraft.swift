import Foundation

public struct TaskDraft {
    public var title: String
    public var description: String
    public var priority: TaskPriority
    public var hasDueDate: Bool
    public var dueDate: Date
    public var projectId: String?

    public init(
        title: String = "",
        description: String = "",
        priority: TaskPriority = .medium,
        dueDateString: String? = nil,
        projectId: String? = nil
    ) {
        self.title = title
        self.description = description
        self.priority = priority
        let parsedDueDate = CalendarViewState.parsedDateOnly(dueDateString)
        self.hasDueDate = parsedDueDate != nil
        self.dueDate = parsedDueDate ?? Date()
        self.projectId = projectId
    }

    public init(_ task: TaskItem) {
        self.init(
            title: task.title,
            description: task.description ?? "",
            priority: task.priority,
            dueDateString: task.dueDate,
            projectId: task.projectId
        )
    }

    public var dueDateString: String? {
        hasDueDate ? CalendarViewState.dayKey(dueDate) : nil
    }

    public var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var trimmedDescription: String? {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public var isValid: Bool {
        !trimmedTitle.isEmpty
    }

    public func createRequest(spaceId: String, includesProject: Bool) -> TaskCreateRequest {
        TaskCreateRequest(
            spaceId: spaceId,
            projectId: includesProject ? projectId : nil,
            title: title,
            description: trimmedDescription,
            priority: priority,
            dueDate: dueDateString
        )
    }

    public func updateRequest(includesProject: Bool) -> TaskUpdateRequest {
        TaskUpdateRequest(
            projectId: includesProject ? projectId : nil,
            title: title,
            description: trimmedDescription,
            priority: priority,
            dueDate: dueDateString
        )
    }
}
