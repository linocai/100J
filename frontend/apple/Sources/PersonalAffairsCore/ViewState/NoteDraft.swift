import Foundation

public struct NoteDraft {
    public var title: String
    public var body: String
    public var type: NoteType

    public init(title: String = "", body: String = "", type: NoteType = .idea) {
        self.title = title
        self.body = body
        self.type = type
    }

    public init(_ note: Note) {
        self.init(title: note.title ?? "", body: note.body, type: note.type)
    }

    public var trimmedTitle: String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public var trimmedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isValid: Bool {
        !trimmedBody.isEmpty
    }

    public func createRequest(spaceId: String) -> NoteCreateRequest {
        NoteCreateRequest(spaceId: spaceId, title: trimmedTitle, body: body, type: type)
    }

    public func updateRequest() -> NoteUpdateRequest {
        NoteUpdateRequest(title: trimmedTitle, body: body, type: type)
    }
}
