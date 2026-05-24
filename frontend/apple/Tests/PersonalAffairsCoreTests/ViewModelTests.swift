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

    // MARK: - v1.2.4 P1-2 (#1, #12): device-session-aware APIClient refresh

    @MainActor
    func test_apiClient_uses_deviceRefresh_when_device_session_active() async throws {
        var seenPaths: [String] = []
        let store = InMemoryTokenStore(accessToken: "stale-access", refreshToken: "jwt-ignored")
        let deviceSession = TestDeviceSessionStore(
            deviceId: "test-device-uuid",
            refreshToken: "device-refresh-token"
        )
        let client = APIClient(
            baseURL: URL(string: "http://unit.test/api/v1")!,
            authMode: .cloudJWT,
            tokenStore: store,
            deviceSession: deviceSession,
            session: Self.stubSession { request in
                seenPaths.append(request.url?.path ?? "")
                let path = request.url?.path ?? ""
                if path == "/api/v1/auth/device-refresh" {
                    let body = try Self.jsonBody(from: request)
                    XCTAssertEqual(body["device_id"] as? String, "test-device-uuid")
                    XCTAssertEqual(body["refresh_token"] as? String, "device-refresh-token")
                    return (200, #"""
                    {"access_token":"new-access","refresh_token":"new-device-refresh","token_type":"bearer","device_id":"test-device-uuid","device_name":"Test","expires_at":"2099-01-01T00:00:00.000Z"}
                    """#)
                }
                XCTAssertEqual(path, "/api/v1/tasks", "JWT /auth/refresh must NOT be called when device session is active")
                let tasksCalls = seenPaths.filter { $0 == "/api/v1/tasks" }.count
                if tasksCalls == 1 {
                    return (401, #"{"error":{"code":"unauthorized","message":"access expired","details":{}}}"#)
                }
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer new-access")
                return (200, #"{"items":[],"next_cursor":null}"#)
            }
        )

        let tasks: [TaskItem] = try await client.fetchAll("/tasks")

        XCTAssertEqual(tasks, [])
        XCTAssertEqual(
            seenPaths,
            ["/api/v1/tasks", "/api/v1/auth/device-refresh", "/api/v1/tasks"],
            "Refresh must go through /auth/device-refresh, not /auth/refresh"
        )
        XCTAssertEqual(store.accessToken, "new-access")
        XCTAssertEqual(store.refreshToken, "new-device-refresh")
        XCTAssertEqual(deviceSession.refreshToken, "new-device-refresh")
    }

    @MainActor
    func test_apiClient_falls_back_to_jwt_refresh_when_no_device_session() async throws {
        var seenPaths: [String] = []
        let store = InMemoryTokenStore(accessToken: "old-access", refreshToken: "jwt-refresh-token")
        let client = APIClient(
            baseURL: URL(string: "http://unit.test/api/v1")!,
            authMode: .cloudJWT,
            tokenStore: store,
            deviceSession: nil,
            session: Self.stubSession { request in
                seenPaths.append(request.url?.path ?? "")
                if request.url?.path == "/api/v1/auth/refresh" {
                    let body = try Self.jsonBody(from: request)
                    XCTAssertEqual(body["refresh_token"] as? String, "jwt-refresh-token")
                    return (200, #"""
                    {"access_token":"jwt-new","refresh_token":"jwt-new-refresh","token_type":"bearer"}
                    """#)
                }
                let tasksCalls = seenPaths.filter { $0 == "/api/v1/tasks" }.count
                if tasksCalls == 1 {
                    return (401, #"{"error":{"code":"unauthorized","message":"expired","details":{}}}"#)
                }
                return (200, #"{"items":[],"next_cursor":null}"#)
            }
        )

        let tasks: [TaskItem] = try await client.fetchAll("/tasks")

        XCTAssertEqual(tasks, [])
        XCTAssertEqual(
            seenPaths,
            ["/api/v1/tasks", "/api/v1/auth/refresh", "/api/v1/tasks"],
            "Without device session, refresh must use /auth/refresh"
        )
        XCTAssertEqual(store.accessToken, "jwt-new")
        XCTAssertEqual(store.refreshToken, "jwt-new-refresh")
    }

    @MainActor
    func test_unauthorized_cooldown_blocks_double_session_expire_within_5s() async throws {
        // Two calls to the same protected path each get a 401 with no
        // refresh path available. The FIRST should clear the token store.
        // The SECOND, fired within the 5s cooldown, must NOT clear the
        // store a second time — otherwise a brand-new token injected by
        // an upstream re-auth between the two errors would be wiped out.
        let store = ResettableInMemoryTokenStore(accessToken: "access", refreshToken: nil)
        let client = APIClient(
            baseURL: URL(string: "http://unit.test/api/v1")!,
            authMode: .cloudJWT,
            tokenStore: store,
            deviceSession: nil,
            session: Self.stubSession { _ in
                (401, #"{"error":{"code":"unauthorized","message":"expired","details":{}}}"#)
            }
        )

        // 1st 401 → unauthorized + token store cleared.
        do {
            let _: [TaskItem] = try await client.fetchAll("/tasks")
            XCTFail("Expected unauthorized")
        } catch APIClientError.unauthorized {
            XCTAssertNil(store.accessToken)
            XCTAssertNil(store.refreshToken)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(store.clearCount, 1)

        // Simulate an upper-layer re-auth that landed JUST after the 1st
        // 401: the store now has a fresh access token but still no
        // refresh token (the new refresh is device-bound, lives in
        // DeviceSessionStore). The next request on the same path must
        // NOT wipe this token out — the cooldown should suppress.
        store.directlySetAccessToken("fresh-access")

        do {
            let _: [TaskItem] = try await client.fetchAll("/tasks")
            XCTFail("Expected unauthorized")
        } catch APIClientError.unauthorized {
            XCTAssertEqual(store.accessToken, "fresh-access", "cooldown must suppress clear()")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(store.clearCount, 1, "no extra clear() while in cooldown")
    }

    private static func space(id: String, type: SpaceType) -> Space {
        Space(id: id, name: type.label, type: type)
    }

    private static func jsonBody(from request: URLRequest) throws -> [String: Any] {
        let data: Data
        if let httpBody = request.httpBody {
            data = httpBody
        } else if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var collected = Data()
            let bufferSize = 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let count = stream.read(buffer, maxLength: bufferSize)
                if count <= 0 { break }
                collected.append(buffer, count: count)
            }
            data = collected
        } else {
            data = Data()
        }
        return (try JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
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

/// Test-only TokenStore that lets tests inject an access token mid-flight
/// (the real InMemoryTokenStore has `private(set)` setters) and counts how
/// many times `clear()` has been called — useful for verifying that the
/// APIClient cooldown actually suppresses repeated clearings.
final class ResettableInMemoryTokenStore: TokenStore {
    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var clearCount = 0

    init(accessToken: String? = nil, refreshToken: String? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    func save(accessToken: String, refreshToken: String) throws {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    func clear() throws {
        accessToken = nil
        refreshToken = nil
        clearCount += 1
    }

    func directlySetAccessToken(_ value: String?) {
        accessToken = value
    }
}

/// In-memory DeviceSessionStore for unit tests — keeps refresh token and
/// info in plain ivars instead of Keychain / UserDefaults so tests stay
/// hermetic and don't pollute the developer's real cloud session.
final class TestDeviceSessionStore: DeviceSessionStore {
    private var _deviceId: String
    private var _refreshToken: String?
    private var _info: DeviceSessionInfo?
    var saveCalls = 0
    var clearAllCalls = 0

    init(deviceId: String, refreshToken: String?) {
        self._deviceId = deviceId
        self._refreshToken = refreshToken
        super.init(
            defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!,
            keychainService: "test-\(UUID().uuidString)"
        )
    }

    override var deviceId: String { _deviceId }

    override var refreshToken: String? { _refreshToken }

    override func saveRefreshToken(_ token: String) throws {
        _refreshToken = token
        saveCalls += 1
    }

    override func clearRefreshToken() {
        _refreshToken = nil
    }

    override var info: DeviceSessionInfo? {
        get { _info }
        set { _info = newValue }
    }

    override func recordIssued(deviceName: String?, expiresAt: Date?) {
        _info = DeviceSessionInfo(
            deviceId: _deviceId,
            deviceName: deviceName ?? "test",
            expiresAt: expiresAt,
            lastRefreshedAt: Date()
        )
    }

    override func clearAll() {
        _refreshToken = nil
        _info = nil
        clearAllCalls += 1
    }

    override var hasActiveSession: Bool {
        _refreshToken != nil
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
