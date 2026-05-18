import Foundation

public final class NoteRepository {
    private let api: APIClient

    public init(api: APIClient) {
        self.api = api
    }

    public func list(status: NoteStatus? = nil, type: NoteType? = nil, search: String? = nil) async throws -> [Note] {
        try await api.fetchAll("/notes", query: noteQuery(status: status, type: type, search: search))
    }

    public func page(
        status: NoteStatus? = nil,
        type: NoteType? = nil,
        search: String? = nil,
        limit: Int = 100,
        cursor: String? = nil
    ) async throws -> PageResponse<Note> {
        var query = noteQuery(status: status, type: type, search: search)
        query.append(URLQueryItem(name: "limit", value: "\(limit)"))
        query.appendIfPresent("cursor", cursor)
        return try await api.send("/notes", query: query, response: PageResponse<Note>.self)
    }

    private func noteQuery(status: NoteStatus?, type: NoteType?, search: String?) -> [URLQueryItem] {
        var query: [URLQueryItem] = []
        query.appendIfPresent("status", status?.rawValue)
        query.appendIfPresent("type", type?.rawValue)
        query.appendIfPresent("search", search?.nilIfBlank)
        return query
    }

    public func create(_ request: NoteCreateRequest) async throws -> Note {
        try await api.send("/notes", method: .post, body: request, response: Note.self)
    }

    public func update(id: String, request: NoteUpdateRequest) async throws -> Note {
        try await api.send("/notes/\(id)", method: .patch, body: request, response: Note.self)
    }

    public func archive(id: String) async throws -> Note {
        try await api.send("/notes/\(id)/archive", method: .post, response: Note.self)
    }

    public func delete(id: String) async throws -> DeleteResponse {
        try await api.send("/notes/\(id)", method: .delete, response: DeleteResponse.self)
    }

    public func convertToTask(noteId: String, request: ConvertNoteToTaskRequest) async throws -> ConvertNoteToTaskResponse {
        try await api.send(
            "/notes/\(noteId)/convert-to-task",
            method: .post,
            body: request,
            response: ConvertNoteToTaskResponse.self
        )
    }
}
