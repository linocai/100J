import Foundation
import XCTest
@testable import PersonalAffairsApp
@testable import PersonalAffairsCore

/// v1.2.4.2 P1-15: contract tests for the inline-quick-add overloads on
/// `AppModel`. These methods are what `InlineQuickAddRow` calls from each
/// Plan tab, so they have to:
///
///   * resolve the right space (personal vs company),
///   * POST a minimal `TaskCreateRequest` / `ProjectCreateRequest` /
///     `NoteCreateRequest` (no agent, no confirmation),
///   * insert the returned model at the top of the matching in-memory
///     array so the new row appears immediately,
///   * return `false` and surface `errorMessage` on failure, with the
///     in-memory array untouched.
///
/// The tests use the same URLProtocol stub pattern as
/// `PersonalAffairsCoreTests` — we just inject a custom `URLSession` into
/// `APIClient` and assert on the requests it tries to send.
@MainActor
final class AppModelInlineCreateTests: XCTestCase {

    func test_createPersonalTask_posts_to_personal_space_and_prepends_to_array() async throws {
        var seenBody: [String: Any] = [:]
        let model = makeModel { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/tasks")
            seenBody = (try? Self.jsonBody(from: request)) ?? [:]
            return (201, Self.taskJSON(id: "task-new", spaceId: "personal-space", title: "买牛奶"))
        }
        model.spaces = Self.seedSpaces()
        model.personalTasks = [Self.seededTask(id: "task-old", spaceId: "personal-space", title: "旧任务")]

        let ok = await model.createPersonalTask(title: "  买牛奶  ")

        XCTAssertTrue(ok, "successful create must return true")
        XCTAssertEqual(seenBody["space_id"] as? String, "personal-space")
        XCTAssertEqual(seenBody["title"] as? String, "买牛奶",
                       "title must be trimmed before POST")
        XCTAssertEqual(model.personalTasks.first?.id, "task-new",
                       "new task must land at the top of personalTasks")
        XCTAssertEqual(model.personalTasks.count, 2)
        XCTAssertNil(model.errorMessage)
    }

    func test_createCompanyTask_posts_to_company_space() async throws {
        var seenBody: [String: Any] = [:]
        let model = makeModel { request in
            seenBody = (try? Self.jsonBody(from: request)) ?? [:]
            return (201, Self.taskJSON(id: "task-c1", spaceId: "company-space", title: "开会"))
        }
        model.spaces = Self.seedSpaces()

        let ok = await model.createCompanyTask(title: "开会")

        XCTAssertTrue(ok)
        XCTAssertEqual(seenBody["space_id"] as? String, "company-space",
                       "company task must resolve to the company space, not personal")
        XCTAssertEqual(model.companyTasks.first?.id, "task-c1")
    }

    func test_createNote_defaults_to_idea_type_with_empty_body() async throws {
        var seenBody: [String: Any] = [:]
        let model = makeModel { request in
            seenBody = (try? Self.jsonBody(from: request)) ?? [:]
            XCTAssertEqual(request.url?.path, "/api/v1/notes")
            return (201, Self.noteJSON(id: "note-1", spaceId: "personal-space", title: "灵感一闪"))
        }
        model.spaces = Self.seedSpaces()

        let ok = await model.createNote(title: "灵感一闪")

        XCTAssertTrue(ok)
        XCTAssertEqual(seenBody["title"] as? String, "灵感一闪")
        XCTAssertEqual(seenBody["body"] as? String, "")
        XCTAssertEqual(seenBody["type"] as? String, "idea",
                       "inline-created notes default to .idea so they land on the Plan notes tab")
        XCTAssertEqual(model.notes.first?.id, "note-1")
    }

    func test_createProject_uses_title_as_name_and_goes_to_company_space() async throws {
        var seenBody: [String: Any] = [:]
        let model = makeModel { request in
            seenBody = (try? Self.jsonBody(from: request)) ?? [:]
            XCTAssertEqual(request.url?.path, "/api/v1/projects")
            return (201, Self.projectJSON(id: "proj-1", spaceId: "company-space", name: "100J 发布"))
        }
        model.spaces = Self.seedSpaces()

        let ok = await model.createProject(name: "100J 发布")

        XCTAssertTrue(ok)
        XCTAssertEqual(seenBody["space_id"] as? String, "company-space")
        XCTAssertEqual(seenBody["name"] as? String, "100J 发布")
        XCTAssertEqual(model.projects.first?.id, "proj-1")
    }

    func test_createCompanyTask_sets_errorMessage_and_returns_false_on_server_error() async {
        let model = makeModel { _ in
            return (500, #"{"detail":"boom"}"#)
        }
        model.spaces = Self.seedSpaces()

        let ok = await model.createCompanyTask(title: "开会")

        XCTAssertFalse(ok, "server 500 must surface as a failure to the row")
        XCTAssertNotNil(model.errorMessage, "AppModel must populate errorMessage so the banner shows")
        XCTAssertTrue(model.companyTasks.isEmpty,
                      "no row may be inserted when the POST fails — the user needs to see the failure")
    }

    func test_blank_input_short_circuits_without_network_call() async {
        var requestCount = 0
        let model = makeModel { _ in
            requestCount += 1
            return (201, "{}")
        }
        model.spaces = Self.seedSpaces()

        let ok = await model.createPersonalTask(title: "   ")

        XCTAssertFalse(ok, "blank titles must not POST")
        XCTAssertEqual(requestCount, 0, "the network must never be touched for blank input")
    }

    // MARK: - Helpers

    private func makeModel(handler: @escaping (URLRequest) throws -> (Int, String)) -> AppModel {
        InlineCreateStubProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [InlineCreateStubProtocol.self]
        let session = URLSession(configuration: configuration)
        let deviceSession = InlineCreateStubDeviceSessionStore()
        let api = APIClient(
            baseURL: URL(string: "http://unit.test/api/v1")!,
            authMode: .localOwner,
            tokenStore: InMemoryTokenStore(),
            deviceSession: deviceSession,
            session: session
        )
        let auth = AuthRepository(api: api)
        return AppModel(
            authMode: .localOwner,
            api: api,
            authRepository: auth,
            deviceSession: deviceSession,
            startsNetworkMonitor: false
        )
    }

    private static func seedSpaces() -> [Space] {
        [
            Space(id: "personal-space", name: "个人", type: .personal),
            Space(id: "company-space", name: "公司", type: .company)
        ]
    }

    private static func seededTask(id: String, spaceId: String, title: String) -> TaskItem {
        TaskItem(
            id: id,
            userId: "user-1",
            spaceId: spaceId,
            projectId: nil,
            title: title,
            description: nil,
            status: .active,
            priority: .medium,
            dueDate: nil,
            remindAt: nil,
            estimatedMinutes: nil,
            source: "manual",
            completedAt: nil,
            archivedAt: nil,
            createdAt: Date(),
            updatedAt: Date(),
            version: 1
        )
    }

    private static func jsonBody(from request: URLRequest) throws -> [String: Any] {
        let data: Data
        if let httpBody = request.httpBody {
            data = httpBody
        } else if let stream = request.httpBodyStream {
            data = Self.readAllData(from: stream)
        } else {
            data = Data()
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static func readAllData(from stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    private static func taskJSON(id: String, spaceId: String, title: String) -> String {
        """
        {
          "id":"\(id)",
          "user_id":"user-1",
          "space_id":"\(spaceId)",
          "project_id":null,
          "title":"\(title)",
          "description":null,
          "status":"active",
          "priority":"medium",
          "due_date":null,
          "remind_at":null,
          "estimated_minutes":null,
          "source":"manual",
          "completed_at":null,
          "archived_at":null,
          "created_at":"2026-05-27T00:00:00Z",
          "updated_at":"2026-05-27T00:00:00Z",
          "version":1
        }
        """
    }

    private static func noteJSON(id: String, spaceId: String, title: String) -> String {
        """
        {
          "id":"\(id)",
          "user_id":"user-1",
          "space_id":"\(spaceId)",
          "title":"\(title)",
          "body":"",
          "type":"idea",
          "status":"active",
          "linked_task_id":null,
          "source":"manual",
          "created_at":"2026-05-27T00:00:00Z",
          "updated_at":"2026-05-27T00:00:00Z",
          "version":1
        }
        """
    }

    private static func projectJSON(id: String, spaceId: String, name: String) -> String {
        """
        {
          "id":"\(id)",
          "user_id":"user-1",
          "space_id":"\(spaceId)",
          "name":"\(name)",
          "description":null,
          "status":"active",
          "start_date":null,
          "target_date":null,
          "completed_at":null,
          "archived_at":null,
          "created_at":"2026-05-27T00:00:00Z",
          "updated_at":"2026-05-27T00:00:00Z",
          "version":1
        }
        """
    }
}

private final class InlineCreateStubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, String))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (status, body) = try Self.handler?(request) ?? (200, "{}")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
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

/// Hermetic DeviceSessionStore — never touches the real Keychain.
private final class InlineCreateStubDeviceSessionStore: DeviceSessionStore {
    init() {
        super.init(
            defaults: UserDefaults(suiteName: "inline-create-\(UUID().uuidString)")!,
            keychainService: "inline-create-\(UUID().uuidString)"
        )
    }
    override var deviceId: String { "inline-create-device" }
    override var refreshToken: String? { nil }
    override var hasActiveSession: Bool { false }
    override func clearAll() {}
}
