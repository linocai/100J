import Combine
import Foundation

@MainActor
public final class ProjectsViewModel: ObservableObject {
    @Published public private(set) var items: [Project] = []
    @Published public var filter: ProjectStatus = .active
    @Published public var search: String = ""
    @Published public private(set) var loading = false
    @Published public private(set) var lastError: APIClientError?

    private let repo: ProjectRepository
    private let companySpace: () -> Space?

    public init(repo: ProjectRepository, companySpace: @escaping () -> Space?) {
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
            items = try await repo.list(
                spaceId: space.id,
                status: filter,
                search: search.nilIfBlank
            )
            lastError = nil
        } catch {
            lastError = viewModelError(from: error)
        }
    }

    public func create(_ draft: ProjectDraft) async {
        guard let space = companySpace() else { return }
        await mutate {
            _ = try await repo.create(draft.createRequest(spaceId: space.id))
        }
    }

    public func update(id: String, draft: ProjectDraft) async {
        await mutate { _ = try await repo.update(id: id, request: draft.updateRequest()) }
    }

    public func complete(_ project: Project) async {
        await mutate { _ = try await repo.complete(id: project.id) }
    }

    public func archive(_ project: Project) async {
        await mutate { _ = try await repo.archive(id: project.id) }
    }

    public func tasks(projectId: String, status: TaskStatus = .active) async -> [TaskItem] {
        do {
            lastError = nil
            return try await repo.tasks(projectId: projectId, status: status)
        } catch {
            lastError = viewModelError(from: error)
            return []
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
