import Combine
import Foundation

@MainActor
public final class CalendarViewModel: ObservableObject {
    @Published public private(set) var items: [CalendarItem] = []
    @Published public var filter: CalendarScopeFilter = .all
    @Published public var selectedProjectId: String?
    @Published public private(set) var loading = false
    @Published public private(set) var lastError: APIClientError?

    private let repo: CalendarRepository
    private let personalSpace: () -> Space?
    private let companySpace: () -> Space?
    private let window: () -> (fromDate: String, toDate: String)

    public init(
        repo: CalendarRepository,
        personalSpace: @escaping () -> Space?,
        companySpace: @escaping () -> Space?,
        window: @escaping () -> (fromDate: String, toDate: String) = { defaultCalendarWindow() }
    ) {
        self.repo = repo
        self.personalSpace = personalSpace
        self.companySpace = companySpace
        self.window = window
    }

    public func reload() async {
        guard let query = CalendarViewState.query(
            filter: filter,
            selectedProjectId: selectedProjectId,
            personalSpaceId: personalSpace()?.id,
            companySpaceId: companySpace()?.id
        ) else {
            items = []
            return
        }
        await reload(query: query)
    }

    public func reload(query: CalendarListQuery) async {
        let range = window()
        loading = true
        defer { loading = false }
        do {
            switch query {
            case .all(let personalSpaceId, let companySpaceId):
                items = try await repo.merged(
                    personalSpaceId: personalSpaceId,
                    companySpaceId: companySpaceId,
                    fromDate: range.fromDate,
                    toDate: range.toDate
                )
            case .personal(let spaceId):
                items = try await repo.list(
                    spaceId: spaceId,
                    fromDate: range.fromDate,
                    toDate: range.toDate
                )
            case .company(let spaceId):
                items = try await repo.list(
                    spaceId: spaceId,
                    fromDate: range.fromDate,
                    toDate: range.toDate
                )
            case .project(let companySpaceId, let projectId):
                items = try await repo.list(
                    spaceId: companySpaceId,
                    projectId: projectId,
                    fromDate: range.fromDate,
                    toDate: range.toDate
                )
            }
            lastError = nil
        } catch {
            lastError = viewModelError(from: error)
        }
    }

    public func create(_ draft: CalendarDraftState) async {
        let targetSpace = draft.spaceType == .personal ? personalSpace() : companySpace()
        guard let space = targetSpace else { return }
        await mutate {
            _ = try await repo.create(draft.createRequest(spaceId: space.id))
        }
    }

    public func update(id: String, draft: CalendarDraftState) async {
        await mutate {
            _ = try await repo.update(id: id, request: draft.updateRequest())
        }
    }

    public func delete(_ item: CalendarItem) async {
        await mutate { _ = try await repo.delete(id: item.id) }
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
