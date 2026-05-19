import Foundation

public struct RegisterRequest: Encodable {
    public let email: String
    public let password: String
    public let displayName: String?
    public let timezone: String

    public init(email: String, password: String, displayName: String?, timezone: String = "America/New_York") {
        self.email = email
        self.password = password
        self.displayName = displayName
        self.timezone = timezone
    }
}

public struct LoginRequest: Encodable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public struct OwnerLoginRequest: Encodable {
    public let accessCode: String

    public init(accessCode: String) {
        self.accessCode = accessCode
    }
}

public struct RefreshRequest: Encodable {
    public let refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

public struct TaskCreateRequest: Encodable {
    public var spaceId: String
    public var projectId: String?
    public var title: String
    public var description: String?
    public var priority: TaskPriority
    public var dueDate: String?
    public var remindAt: Date?
    public var estimatedMinutes: Int?

    public init(
        spaceId: String,
        projectId: String? = nil,
        title: String,
        description: String? = nil,
        priority: TaskPriority = .medium,
        dueDate: String? = nil,
        remindAt: Date? = nil,
        estimatedMinutes: Int? = nil
    ) {
        self.spaceId = spaceId
        self.projectId = projectId
        self.title = title
        self.description = description
        self.priority = priority
        self.dueDate = dueDate
        self.remindAt = remindAt
        self.estimatedMinutes = estimatedMinutes
    }
}

public struct TaskUpdateRequest: Encodable {
    public var projectId: String?
    public var title: String?
    public var description: String?
    public var priority: TaskPriority?
    public var dueDate: String?
    public var remindAt: Date?
    public var estimatedMinutes: Int?
    public var status: TaskStatus?

    public init(
        projectId: String? = nil,
        title: String? = nil,
        description: String? = nil,
        priority: TaskPriority? = nil,
        dueDate: String? = nil,
        remindAt: Date? = nil,
        estimatedMinutes: Int? = nil,
        status: TaskStatus? = nil
    ) {
        self.projectId = projectId
        self.title = title
        self.description = description
        self.priority = priority
        self.dueDate = dueDate
        self.remindAt = remindAt
        self.estimatedMinutes = estimatedMinutes
        self.status = status
    }
}

public struct ProjectCreateRequest: Encodable {
    public var spaceId: String
    public var name: String
    public var description: String?
    public var startDate: String?
    public var targetDate: String?

    public init(spaceId: String, name: String, description: String? = nil, startDate: String? = nil, targetDate: String? = nil) {
        self.spaceId = spaceId
        self.name = name
        self.description = description
        self.startDate = startDate
        self.targetDate = targetDate
    }
}

public struct ProjectUpdateRequest: Encodable {
    public var name: String?
    public var description: String?
    public var startDate: String?
    public var targetDate: String?
    public var status: ProjectStatus?

    public init(name: String? = nil, description: String? = nil, startDate: String? = nil, targetDate: String? = nil, status: ProjectStatus? = nil) {
        self.name = name
        self.description = description
        self.startDate = startDate
        self.targetDate = targetDate
        self.status = status
    }
}

public struct CalendarItemCreateRequest: Encodable {
    public var spaceId: String
    public var title: String
    public var description: String?
    public var type: CalendarItemType
    public var allDay: Bool
    public var startDate: String?
    public var endDate: String?
    public var startAt: Date?
    public var endAt: Date?
    public var timezone: String
    public var recurrence: Recurrence
    public var remindAt: Date?
    public var projectId: String?
    public var relatedTaskId: String?

    public init(
        spaceId: String,
        title: String,
        description: String? = nil,
        type: CalendarItemType = .appointment,
        allDay: Bool = false,
        startDate: String? = nil,
        endDate: String? = nil,
        startAt: Date? = nil,
        endAt: Date? = nil,
        timezone: String = TimeZone.current.identifier,
        recurrence: Recurrence = .none,
        remindAt: Date? = nil,
        projectId: String? = nil,
        relatedTaskId: String? = nil
    ) {
        self.spaceId = spaceId
        self.title = title
        self.description = description
        self.type = type
        self.allDay = allDay
        self.startDate = startDate
        self.endDate = endDate
        self.startAt = startAt
        self.endAt = endAt
        self.timezone = timezone
        self.recurrence = recurrence
        self.remindAt = remindAt
        self.projectId = projectId
        self.relatedTaskId = relatedTaskId
    }
}

public struct CalendarItemUpdateRequest: Encodable {
    public var title: String?
    public var description: String?
    public var type: CalendarItemType?
    public var allDay: Bool?
    public var startDate: String?
    public var endDate: String?
    public var startAt: Date?
    public var endAt: Date?
    public var timezone: String?
    public var recurrence: Recurrence?
    public var remindAt: Date?
    public var projectId: String?
    public var relatedTaskId: String?

    public init(title: String? = nil, description: String? = nil, type: CalendarItemType? = nil, allDay: Bool? = nil, startDate: String? = nil, endDate: String? = nil, startAt: Date? = nil, endAt: Date? = nil, timezone: String? = nil, recurrence: Recurrence? = nil, remindAt: Date? = nil, projectId: String? = nil, relatedTaskId: String? = nil) {
        self.title = title
        self.description = description
        self.type = type
        self.allDay = allDay
        self.startDate = startDate
        self.endDate = endDate
        self.startAt = startAt
        self.endAt = endAt
        self.timezone = timezone
        self.recurrence = recurrence
        self.remindAt = remindAt
        self.projectId = projectId
        self.relatedTaskId = relatedTaskId
    }
}

public struct NoteCreateRequest: Encodable {
    public var spaceId: String
    public var title: String?
    public var body: String
    public var type: NoteType

    public init(spaceId: String, title: String? = nil, body: String, type: NoteType = .idea) {
        self.spaceId = spaceId
        self.title = title
        self.body = body
        self.type = type
    }
}

public struct NoteUpdateRequest: Encodable {
    public var title: String?
    public var body: String?
    public var type: NoteType?
    public var status: NoteStatus?

    public init(title: String? = nil, body: String? = nil, type: NoteType? = nil, status: NoteStatus? = nil) {
        self.title = title
        self.body = body
        self.type = type
        self.status = status
    }
}

public struct ConvertNoteToTaskRequest: Encodable {
    public var title: String
    public var priority: TaskPriority
    public var dueDate: String?

    public init(title: String, priority: TaskPriority = .medium, dueDate: String? = nil) {
        self.title = title
        self.priority = priority
        self.dueDate = dueDate
    }
}

public struct LLMKeyRequest: Encodable {
    public var provider: String
    public var apiKey: String

    public init(provider: String, apiKey: String) {
        self.provider = provider
        self.apiKey = apiKey
    }
}

public struct AgentCommandRequest: Encodable {
    public var command: String
    public var arguments: [String: JSONValue]
    public var dryRun: Bool

    public init(command: String, arguments: [String: JSONValue] = [:], dryRun: Bool = false) {
        self.command = command
        self.arguments = arguments
        self.dryRun = dryRun
    }
}

public struct AgentConfirmRequest: Encodable {
    public var confirmationToken: String

    public init(confirmationToken: String) {
        self.confirmationToken = confirmationToken
    }
}
