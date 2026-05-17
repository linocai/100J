import Foundation

public struct User: Codable, Identifiable, Equatable {
    public let id: String
    public let email: String?
    public let displayName: String?
    public let timezone: String
}

public struct Space: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let type: SpaceType
}

public struct TaskItem: Codable, Identifiable, Equatable {
    public let id: String
    public let userId: String
    public let spaceId: String
    public let projectId: String?
    public let title: String
    public let description: String?
    public let status: TaskStatus
    public let priority: TaskPriority
    public let dueDate: String?
    public let remindAt: Date?
    public let estimatedMinutes: Int?
    public let source: String
    public let completedAt: Date?
    public let archivedAt: Date?
    public let createdAt: Date
    public let updatedAt: Date
    public let version: Int
}

public struct Project: Codable, Identifiable, Equatable {
    public let id: String
    public let userId: String
    public let spaceId: String
    public let name: String
    public let description: String?
    public let status: ProjectStatus
    public let startDate: String?
    public let targetDate: String?
    public let completedAt: Date?
    public let archivedAt: Date?
    public let createdAt: Date
    public let updatedAt: Date
    public let version: Int
}

public struct CalendarItem: Codable, Identifiable, Equatable {
    public let id: String
    public let userId: String
    public let spaceId: String
    public let projectId: String?
    public let relatedTaskId: String?
    public let title: String
    public let description: String?
    public let type: CalendarItemType
    public let allDay: Bool
    public let startDate: String?
    public let endDate: String?
    public let startAt: Date?
    public let endAt: Date?
    public let timezone: String
    public let recurrence: Recurrence?
    public let remindAt: Date?
    public let source: String
    public let createdAt: Date
    public let updatedAt: Date
    public let version: Int
}

public struct Note: Codable, Identifiable, Equatable {
    public let id: String
    public let userId: String
    public let spaceId: String
    public let title: String?
    public let body: String
    public let type: NoteType
    public let status: NoteStatus
    public let linkedTaskId: String?
    public let source: String
    public let createdAt: Date
    public let updatedAt: Date
    public let version: Int
}

public struct LLMKey: Codable, Equatable {
    public let provider: String
    public let keyPreview: String?
    public let isActive: Bool
}

public struct AgentTool: Codable, Identifiable, Equatable {
    public var id: String { name }
    public let name: String
    public let description: String
    public let parametersSchema: [String: JSONValue]
}

public struct AgentActionLog: Codable, Identifiable, Equatable {
    public let id: String
    public let userId: String
    public let actionType: String
    public let targetType: String?
    public let targetId: String?
    public let requestPayload: [String: JSONValue]?
    public let resultPayload: [String: JSONValue]?
    public let status: String
    public let errorMessage: String?
    public let createdAt: Date
}

public struct DeleteResponse: Codable, Equatable {
    public let id: String
    public let deletedAt: Date
}

