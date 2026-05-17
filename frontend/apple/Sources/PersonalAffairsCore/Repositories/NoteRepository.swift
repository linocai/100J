import Foundation

public final class NoteRepository {
    private let api: APIClient

    public init(api: APIClient) {
        self.api = api
    }

    public func list(status: NoteStatus? = nil, type: NoteType? = nil, search: String? = nil) async throws -> [Note] {
        var query: [URLQueryItem] = []
        query.appendIfPresent("status", status?.rawValue)
        query.appendIfPresent("type", type?.rawValue)
        query.appendIfPresent("search", search?.nilIfBlank)
        let response: PageResponse<Note> = try await api.send("/notes", query: query, response: PageResponse<Note>.self)
        return response.items
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

