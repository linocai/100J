import Combine
import Foundation

@MainActor
public final class NotesViewModel: ObservableObject {
    @Published public private(set) var items: [Note] = []
    @Published public var status: NoteStatus = .active
    @Published public var type: NoteType?
    @Published public var search: String = ""
    @Published public private(set) var loading = false
    @Published public private(set) var lastError: APIClientError?

    private let repo: NoteRepository
    private let personalSpace: () -> Space?

    public init(repo: NoteRepository, personalSpace: @escaping () -> Space?) {
        self.repo = repo
        self.personalSpace = personalSpace
    }

    public func reload() async {
        loading = true
        defer { loading = false }
        do {
            items = try await repo.list(status: status, type: type, search: search.nilIfBlank)
            lastError = nil
        } catch {
            lastError = viewModelError(from: error)
        }
    }

    public func create(_ draft: NoteDraft) async {
        guard let space = personalSpace() else { return }
        await mutate {
            _ = try await repo.create(draft.createRequest(spaceId: space.id))
        }
    }

    public func update(id: String, draft: NoteDraft) async {
        await mutate { _ = try await repo.update(id: id, request: draft.updateRequest()) }
    }

    public func archive(_ note: Note) async {
        await mutate { _ = try await repo.archive(id: note.id) }
    }

    public func convertToTask(_ note: Note) async {
        let title = note.title?.nilIfBlank ?? String(note.body.prefix(48))
        await mutate {
            _ = try await repo.convertToTask(noteId: note.id, request: ConvertNoteToTaskRequest(title: title))
        }
    }

    private func mutate(_ operation: () async throws -> Void) async {
        loading = true
        defer { loading = false }
        do {
            try await operation()
            lastError = nil
            await reload()
        } catch {
            lastError = viewModelError(from: error)
        }
    }
}
