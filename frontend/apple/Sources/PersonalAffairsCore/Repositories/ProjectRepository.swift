import Foundation

public final class ProjectRepository {
    private let api: APIClient

    public init(api: APIClient) {
        self.api = api
    }

    public func list(spaceId: String? = nil, status: ProjectStatus? = nil, search: String? = nil) async throws -> [Project] {
        var query: [URLQueryItem] = []
        query.appendIfPresent("space_id", spaceId)
        query.appendIfPresent("status", status?.rawValue)
        query.appendIfPresent("search", search?.nilIfBlank)
        let response: PageResponse<Project> = try await api.send("/projects", query: query, response: PageResponse<Project>.self)
        return response.items
    }

    public func create(_ request: ProjectCreateRequest) async throws -> Project {
        try await api.send("/projects", method: .post, body: request, response: Project.self)
    }

    public func update(id: String, request: ProjectUpdateRequest) async throws -> Project {
        try await api.send("/projects/\(id)", method: .patch, body: request, response: Project.self)
    }

    public func complete(id: String) async throws -> Project {
        try await api.send("/projects/\(id)/complete", method: .post, response: Project.self)
    }

    public func archive(id: String) async throws -> Project {
        try await api.send("/projects/\(id)/archive", method: .post, response: Project.self)
    }

    public func delete(id: String) async throws -> DeleteResponse {
        try await api.send("/projects/\(id)", method: .delete, response: DeleteResponse.self)
    }

    public func tasks(projectId: String, status: TaskStatus? = nil) async throws -> [TaskItem] {
        var query: [URLQueryItem] = []
        query.appendIfPresent("status", status?.rawValue)
        let response: PageResponse<TaskItem> = try await api.send(
            "/projects/\(projectId)/tasks",
            query: query,
            response: PageResponse<TaskItem>.self
        )
        return response.items
    }
}

