import Foundation
import XCTest
@testable import PersonalAffairsCore

final class ViewModelTests: XCTestCase {
    @MainActor
    func testPersonalTasksViewModelReloadsAndCompletesThroughRepository() async throws {
        var sawComplete = false
        let client = APIClient(
            baseURL: URL(string: "http://unit.test/api/v1")!,
            authMode: .localOwner,
            tokenStore: InMemoryTokenStore(),
            session: Self.stubSession { request in
                if request.url?.path == "/api/v1/tasks/task-1/complete" {
                    sawComplete = true
                    return (200, Self.taskJSON(id: "task-1", spaceId: "personal", title: "Receipt", status: "done"))
                }
                XCTAssertEqual(request.url?.path, "/api/v1/tasks")
                let query = Self.queryItems(from: request)
                XCTAssertEqual(query["space_id"], "personal")
                XCTAssertEqual(query["status"], "active")
                XCTAssertEqual(query["search"], "receipt")
                return (200, #"{"items":[\#(Self.taskJSON(id: "task-1", spaceId: "personal", title: "Receipt"))],"next_cursor":null}"#)
            }
        )
        let viewModel = PersonalTasksViewModel(
            repo: TaskRepository(api: client),
            personalSpace: { Self.space(id: "personal", type: .personal) }
        )
        viewModel.search = " receipt "

        await viewModel.reload()
        XCTAssertEqual(viewModel.items.map(\.id), ["task-1"])
        await viewModel.complete(viewModel.items[0])

        XCTAssertTrue(sawComplete)
        XCTAssertNil(viewModel.lastError)
    }

    @MainActor
    func testCompanyTasksViewModelUsesSharedScopeQuery() async throws {
        let client = APIClient(
            baseURL: URL(string: "http://unit.test/api/v1")!,
            authMode: .localOwner,
            tokenStore: InMemoryTokenStore(),
            session: Self.stubSession { request in
                XCTAssertEqual(request.url?.path, "/api/v1/tasks")
                let query = Self.queryItems(from: request)
                XCTAssertEqual(query["space_id"], "company")
                XCTAssertEqual(query["project_scope"], "with_project")
                XCTAssertEqual(query["status"], "active")
                return (200, #"{"items":[],"next_cursor":null}"#)
            }
        )
        let viewModel = CompanyTasksViewModel(
            repo: TaskRepository(api: client),
            companySpace: { Self.space(id: "company", type: .company) }
        )
        viewModel.scope = .withProject

        await viewModel.reload()

        XCTAssertEqual(viewModel.items, [])
        XCTAssertNil(viewModel.lastError)
    }

    @MainActor
    func testCalendarViewModelLoadsProjectScopedCalendar() async throws {
        let client = APIClient(
            baseURL: URL(string: "http://unit.test/api/v1")!,
            authMode: .localOwner,
            tokenStore: InMemoryTokenStore(),
            session: Self.stubSession { request in
                XCTAssertEqual(request.url?.path, "/api/v1/calendar-items")
                let query = Self.queryItems(from: request)
                XCTAssertEqual(query["space_id"], "company")
                XCTAssertEqual(query["project_id"], "project-1")
                XCTAssertEqual(query["from_date"], "2026-05-01")
                XCTAssertEqual(query["to_date"], "2026-05-31")
                return (200, #"{"items":[\#(Self.calendarItemJSON(id: "calendar-1", spaceId: "company", title: "Review"))],"next_cursor":null}"#)
            }
        )
        let viewModel = CalendarViewModel(
            repo: CalendarRepository(api: client),
            personalSpace: { Self.space(id: "personal", type: .personal) },
            companySpace: { Self.space(id: "company", type: .company) },
            window: { ("2026-05-01", "2026-05-31") }
        )
        viewModel.filter = .project
        viewModel.selectedProjectId = "project-1"

        await viewModel.reload()

        XCTAssertEqual(viewModel.items.map(\.id), ["calendar-1"])
        XCTAssertNil(viewModel.lastError)
    }

    @MainActor
    func testAgentViewModelHandlesRequiresConfirmationAndConfirm() async throws {
        var sawConfirm = false
        let client = APIClient(
            baseURL: URL(string: "http://unit.test/api/v1")!,
            authMode: .localOwner,
            tokenStore: InMemoryTokenStore(),
            session: Self.stubSession { request in
                if request.url?.path == "/api/v1/agent/commands/confirm" {
                    sawConfirm = true
                    return (200, #"{"status":"success","result":{"type":"project","id":"project-1"},"would_execute":null,"reason":null,"confirmation_token":null}"#)
                }
                XCTAssertEqual(request.url?.path, "/api/v1/agent/commands")
                return (200, #"{"status":"requires_confirmation","result":null,"would_execute":null,"reason":"Archive project","confirmation_token":"token-1"}"#)
            }
        )
        let viewModel = AgentViewModel(
            repo: AgentRepository(api: client),
            personalSpace: { Self.space(id: "personal", type: .personal) },
            companySpace: { Self.space(id: "company", type: .company) }
        )
        viewModel.review = AgentReviewSession(
            pendingCommand: AgentCommandDraft(
                intent: ParsedCaptureIntent(target: .companyProject, title: "Release"),
                command: "archive_project",
                arguments: ["project_id": .string("project-1")],
                summary: "归档公司项目：Release"
            )
        )

        await viewModel.execute(dryRun: false)
        XCTAssertEqual(viewModel.pendingConfirmation?.token, "token-1")
        XCTAssertFalse(viewModel.pendingConfirmation?.summary.contains("token-1") ?? true)

        await viewModel.confirm()
        XCTAssertTrue(sawConfirm)
        XCTAssertNil(viewModel.review.pendingConfirmation)
        XCTAssertNil(viewModel.review.pendingCommand)
        XCTAssertNil(viewModel.lastError)
    }

    private static func space(id: String, type: SpaceType) -> Space {
        Space(id: id, name: type.label, type: type)
    }

    private static func stubSession(
        handler: @escaping (URLRequest) throws -> (Int, String)
    ) -> URLSession {
        ViewModelStubURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ViewModelStubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func queryItems(from request: URLRequest) -> [String: String] {
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.value.map { (item.name, $0) }
        })
    }

    private static func taskJSON(
        id: String,
        spaceId: String,
        title: String,
        status: String = "active",
        projectId: String? = nil
    ) -> String {
        """
        {
          "id":"\(id)",
          "user_id":"user-1",
          "space_id":"\(spaceId)",
          "project_id":\(projectId.map { "\"\($0)\"" } ?? "null"),
          "title":"\(title)",
          "description":null,
          "status":"\(status)",
          "priority":"medium",
          "due_date":null,
          "remind_at":null,
          "estimated_minutes":null,
          "source":"manual",
          "completed_at":null,
          "archived_at":null,
          "created_at":"2026-05-18T00:00:00Z",
          "updated_at":"2026-05-18T00:00:00Z",
          "version":1
        }
        """
    }

    private static func calendarItemJSON(id: String, spaceId: String, title: String) -> String {
        """
        {
          "id":"\(id)",
          "user_id":"user-1",
          "space_id":"\(spaceId)",
          "project_id":"project-1",
          "related_task_id":null,
          "title":"\(title)",
          "description":null,
          "type":"appointment",
          "all_day":true,
          "start_date":"2026-05-18",
          "end_date":null,
          "start_at":null,
          "end_at":null,
          "timezone":"Asia/Shanghai",
          "recurrence":"none",
          "remind_at":null,
          "source":"manual",
          "created_at":"2026-05-18T00:00:00Z",
          "updated_at":"2026-05-18T00:00:00Z",
          "version":1
        }
        """
    }
}

private final class ViewModelStubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, String))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let (statusCode, body) = try Self.handler?(request) ?? (200, "{}")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
