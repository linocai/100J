import Combine
import Foundation

@MainActor
public final class PersonalTasksViewModel: ObservableObject {
    @Published public private(set) var items: [TaskItem] = []
    @Published public var filter: TaskStatus = .active
    @Published public var search: String = ""
    @Published public private(set) var loading = false
    @Published public private(set) var lastError: APIClientError?

    private let repo: TaskRepository
    private let personalSpace: () -> Space?

    public init(repo: TaskRepository, personalSpace: @escaping () -> Space?) {
        self.repo = repo
        self.personalSpace = personalSpace
    }

    public func reload() async {
        guard let space = personalSpace() else {
            items = []
            return
        }
        loading = true
        defer { loading = false }
        do {
            let query = PersonalTasksViewState.query(
                personalSpaceId: space.id,
                status: filter,
                search: search.nilIfBlank
            )
            items = try await repo.list(query: query)
            lastError = nil
        } catch {
            lastError = viewModelError(from: error)
        }
    }

    public func create(_ draft: TaskDraft) async {
        guard let space = personalSpace() else { return }
        await mutate {
            _ = try await repo.create(draft.createRequest(spaceId: space.id, includesProject: false))
        }
    }

    public func update(id: String, draft: TaskDraft) async {
        await mutate {
            _ = try await repo.update(id: id, request: draft.updateRequest(includesProject: false))
        }
    }

    public func complete(_ task: TaskItem) async {
        await mutate { _ = try await repo.complete(id: task.id) }
    }

    public func reopen(_ task: TaskItem) async {
        await mutate { _ = try await repo.reopen(id: task.id) }
    }

    public func toggleDone(_ task: TaskItem) async {
        if task.status == .done {
            await reopen(task)
        } else {
            await complete(task)
        }
    }

    public func archive(_ task: TaskItem) async {
        await mutate { _ = try await repo.archive(id: task.id) }
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
