import Combine
import Foundation

@MainActor
public final class CompanyTasksViewModel: ObservableObject {
    @Published public private(set) var items: [TaskItem] = []
    @Published public var filter: TaskStatus = .active
    @Published public var search: String = ""
    @Published public var scope: CompanyTaskScope = .all
    @Published public private(set) var loading = false
    @Published public private(set) var lastError: APIClientError?

    private let repo: TaskRepository
    private let companySpace: () -> Space?

    public init(repo: TaskRepository, companySpace: @escaping () -> Space?) {
        self.repo = repo
        self.companySpace = companySpace
    }

    public func reload() async {
        guard let space = companySpace() else {
            items = []
            return
        }
        loading = true
        defer { loading = false }
        do {
            let query = scope.query(
                companySpaceId: space.id,
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
        guard let space = companySpace() else { return }
        await mutate {
            _ = try await repo.create(draft.createRequest(spaceId: space.id, includesProject: true))
        }
    }

    public func createProjectTask(_ draft: TaskDraft, projectId: String) async {
        guard let space = companySpace() else { return }
        var pinnedDraft = draft
        pinnedDraft.projectId = projectId
        await mutate {
            _ = try await repo.create(pinnedDraft.createRequest(spaceId: space.id, includesProject: true))
        }
    }

    public func update(id: String, draft: TaskDraft) async {
        await mutate {
            _ = try await repo.update(id: id, request: draft.updateRequest(includesProject: true))
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
