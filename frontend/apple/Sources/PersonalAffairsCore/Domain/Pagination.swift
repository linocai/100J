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
}

public struct ConvertNoteToTaskResponse: Codable, Equatable {
    public let task: TaskItem
    public let note: Note
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

