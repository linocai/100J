import Foundation

public final class TaskRepository {
    private let api: APIClient

    public init(api: APIClient) {
        self.api = api
    }

    public func list(
        spaceId: String? = nil,
        projectId: String? = nil,
        projectScope: String? = nil,
        status: TaskStatus? = nil,
        priority: TaskPriority? = nil,
        search: String? = nil
    ) async throws -> [TaskItem] {
        try await api.fetchAll("/tasks", query: taskQuery(
            spaceId: spaceId,
            projectId: projectId,
            projectScope: projectScope,
            status: status,
            priority: priority,
            search: search
        ))
    }

    public func page(
        spaceId: String? = nil,
        projectId: String? = nil,
        projectScope: String? = nil,
        status: TaskStatus? = nil,
        priority: TaskPriority? = nil,
        search: String? = nil,
        limit: Int = 100,
        cursor: String? = nil
    ) async throws -> PageResponse<TaskItem> {
        var query = taskQuery(
            spaceId: spaceId,
            projectId: projectId,
            projectScope: projectScope,
            status: status,
            priority: priority,
            search: search
        )
        query.append(URLQueryItem(name: "limit", value: "\(limit)"))
        query.appendIfPresent("cursor", cursor)
        return try await api.send("/tasks", query: query, response: PageResponse<TaskItem>.self)
    }

    private func taskQuery(
        spaceId: String?,
        projectId: String?,
        projectScope: String?,
        status: TaskStatus?,
        priority: TaskPriority?,
        search: String?
    ) -> [URLQueryItem] {
        var query: [URLQueryItem] = []
        query.appendIfPresent("space_id", spaceId)
        query.appendIfPresent("project_id", projectId)
        query.appendIfPresent("project_scope", projectScope)
        query.appendIfPresent("status", status?.rawValue)
        query.appendIfPresent("priority", priority?.rawValue)
        query.appendIfPresent("search", search?.nilIfBlank)
        return query
    }

    public func create(_ request: TaskCreateRequest) async throws -> TaskItem {
        try await api.send("/tasks", method: .post, body: request, response: TaskItem.self)
    }

    public func update(id: String, request: TaskUpdateRequest) async throws -> TaskItem {
        try await api.send("/tasks/\(id)", method: .patch, body: request, response: TaskItem.self)
    }

    public func complete(id: String) async throws -> TaskItem {
        try await api.send("/tasks/\(id)/complete", method: .post, response: TaskItem.self)
    }

    public func reopen(id: String) async throws -> TaskItem {
        try await api.send("/tasks/\(id)/reopen", method: .post, response: TaskItem.self)
    }

    public func archive(id: String) async throws -> TaskItem {
        try await api.send("/tasks/\(id)/archive", method: .post, response: TaskItem.self)
    }

    public func delete(id: String) async throws -> DeleteResponse {
        try await api.send("/tasks/\(id)", method: .delete, response: DeleteResponse.self)
    }
}
