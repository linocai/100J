import Foundation

public struct PageResponse<Item: Codable>: Codable {
    public let items: [Item]
    public let nextCursor: String?
}

public struct SpaceListResponse: Codable {
    public let items: [Space]
    public let nextCursor: String?
}

public struct TokenResponse: Codable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let tokenType: String
    // v1.1.2: 当客户端附带 device_id 时，服务器在此返回 device 元数据。
    public let deviceId: String?
    public let deviceName: String?
    public let expiresAt: String?

    public init(
        accessToken: String,
        refreshToken: String,
        tokenType: String,
        deviceId: String? = nil,
        deviceName: String? = nil,
        expiresAt: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.expiresAt = expiresAt
    }
}

public struct ConvertNoteToTaskResponse: Codable, Equatable {
    public let task: TaskItem
    public let note: Note
}

public struct SeedDemoResponse: Codable, Equatable {
    public let tasks: [TaskItem]
    public let calendarItems: [CalendarItem]
    public let created: [String: Int]
}

public struct AgentToolsResponse: Codable, Equatable {
    public let tools: [AgentTool]
}

public struct AgentCommandResponse: Codable, Equatable {
    public let status: String
    public let result: [String: JSONValue]?
    public let wouldExecute: [String: JSONValue]?
    public let reason: String?
    public let confirmationToken: String?
}
