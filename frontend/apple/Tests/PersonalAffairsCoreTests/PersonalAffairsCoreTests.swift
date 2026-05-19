import XCTest
@testable import PersonalAffairsCore

final class PersonalAffairsCoreTests: XCTestCase {
    func testTaskDecodesSnakeCaseAndDates() throws {
        let json = """
        {
          "id": "task-1",
          "user_id": "user-1",
          "space_id": "space-1",
          "project_id": null,
          "title": "整理材料",
          "description": null,
          "status": "active",
          "priority": "medium",
          "due_date": "2026-06-01",
          "remind_at": null,
          "estimated_minutes": null,
          "source": "manual",
          "completed_at": null,
          "archived_at": null,
          "created_at": "2026-05-17T10:00:00Z",
          "updated_at": "2026-05-17T10:00:00Z",
          "version": 1
        }
        """.data(using: .utf8)!

        let task = try JSONDecoder.personalAffairs.decode(TaskItem.self, from: json)

        XCTAssertEqual(task.id, "task-1")
        XCTAssertEqual(task.spaceId, "space-1")
        XCTAssertEqual(task.dueDate, "2026-06-01")
        XCTAssertEqual(task.status, .active)
    }

    func testTaskDecodesBackendNaiveDates() throws {
        let json = """
        {
          "id": "task-1",
          "user_id": "user-1",
          "space_id": "space-1",
          "project_id": null,
          "title": "SQLite date",
          "description": null,
          "status": "active",
          "priority": "medium",
          "due_date": null,
          "remind_at": null,
          "estimated_minutes": null,
          "source": "manual",
          "completed_at": null,
          "archived_at": null,
          "created_at": "2026-05-18T01:35:20.503731",
          "updated_at": "2026-05-18T01:35:20",
          "version": 1
        }
        """.data(using: .utf8)!

        let task = try JSONDecoder.personalAffairs.decode(TaskItem.self, from: json)

        XCTAssertEqual(task.id, "task-1")
    }

    func testRequestEncodesCamelCaseToSnakeCase() throws {
        let request = TaskCreateRequest(
            spaceId: "space-1",
            projectId: nil,
            title: "Company loose task",
            priority: .high,
            dueDate: "2026-06-10"
        )

        let data = try JSONEncoder.personalAffairs.encode(request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(object?["space_id"] as? String, "space-1")
        XCTAssertEqual(object?["due_date"] as? String, "2026-06-10")
        XCTAssertEqual(object?["priority"] as? String, "high")
    }

    func testJSONValueConvertsDictionary() {
        let value = JSONValue.fromAny([
            "title": "Agent task",
            "count": 2,
            "dry": true
        ])

        guard case .object(let object) = value else {
            XCTFail("Expected object")
            return
        }

        XCTAssertEqual(object["title"], .string("Agent task"))
        XCTAssertEqual(object["count"], .number(2))
        XCTAssertEqual(object["dry"], .bool(true))
    }

    func testLocalOwnerModeDoesNotSendAuthorizationHeader() async throws {
        let store = InMemoryTokenStore(accessToken: "access-token", refreshToken: "refresh-token")
        let client = APIClient(baseURL: URL(string: "http://unit.test/api/v1")!, authMode: .localOwner, tokenStore: store, session: Self.stubSession { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            return (200, "{}")
        })

        _ = try await client.send("/health", response: EmptyResponse.self)
    }

    func testCloudJWTModeSendsAuthorizationHeader() async throws {
        let store = InMemoryTokenStore(accessToken: "access-token", refreshToken: "refresh-token")
        let client = APIClient(baseURL: URL(string: "http://unit.test/api/v1")!, authMode: .cloudJWT, tokenStore: store, session: Self.stubSession { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
            return (200, "{}")
        })

        _ = try await client.send("/health", response: EmptyResponse.self)
    }

    func testFetchAllFollowsPagination() async throws {
        var seenCursors: [String?] = []
        let client = APIClient(baseURL: URL(string: "http://unit.test/api/v1")!, authMode: .localOwner, tokenStore: InMemoryTokenStore(), session: Self.stubSession { request in
            let cursor = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "cursor" }?
                .value
            seenCursors.append(cursor)
            if cursor == nil {
                return (200, #"{"items":[{"id":"a","name":"A","type":"personal"}],"next_cursor":"1"}"#)
            }
            return (200, #"{"items":[{"id":"b","name":"B","type":"company"}],"next_cursor":null}"#)
        })

        let spaces: [Space] = try await client.fetchAll("/spaces")

        XCTAssertEqual(spaces.map(\.id), ["a", "b"])
        XCTAssertEqual(seenCursors.count, 2)
        XCTAssertNil(seenCursors[0])
        XCTAssertEqual(seenCursors[1], "1")
    }

    func testTaskRepositoryMapsSharedQueryToRequestParameters() async throws {
        let client = APIClient(baseURL: URL(string: "http://unit.test/api/v1")!, authMode: .localOwner, tokenStore: InMemoryTokenStore(), session: Self.stubSession { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/tasks")
            let query = Self.queryItems(from: request)
            XCTAssertEqual(query["space_id"], "company")
            XCTAssertEqual(query["project_scope"], "with_project")
            XCTAssertEqual(query["status"], "active")
            XCTAssertEqual(query["priority"], "high")
            XCTAssertEqual(query["search"], "invoice")
            XCTAssertEqual(query["limit"], "100")
            return (200, #"{"items":[],"next_cursor":null}"#)
        })
        let repository = TaskRepository(api: client)

        let items = try await repository.list(
            query: TaskListQuery(
                spaceId: "company",
                projectScope: "with_project",
                status: .active,
                priority: .high,
                search: "invoice"
            )
        )

        XCTAssertEqual(items, [])
    }

    func testProjectRepositoryProjectTasksUsesNestedRouteAndStatusQuery() async throws {
        let client = APIClient(baseURL: URL(string: "http://unit.test/api/v1")!, authMode: .localOwner, tokenStore: InMemoryTokenStore(), session: Self.stubSession { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/projects/project-1/tasks")
            let query = Self.queryItems(from: request)
            XCTAssertEqual(query["status"], "active")
            XCTAssertEqual(query["limit"], "100")
            return (200, #"{"items":[],"next_cursor":null}"#)
        })
        let repository = ProjectRepository(api: client)

        let items = try await repository.tasks(projectId: "project-1", status: .active)

        XCTAssertEqual(items, [])
    }

    func testCalendarRepositoryMergedFetchesBothSpacesAndSortsItems() async throws {
        var seenSpaceIds: Set<String> = []
        let client = APIClient(baseURL: URL(string: "http://unit.test/api/v1")!, authMode: .localOwner, tokenStore: InMemoryTokenStore(), session: Self.stubSession { request in
            XCTAssertEqual(request.url?.path, "/api/v1/calendar-items")
            let query = Self.queryItems(from: request)
            XCTAssertEqual(query["from_date"], "2026-05-01")
            XCTAssertEqual(query["to_date"], "2026-05-31")
            let spaceId = try XCTUnwrap(query["space_id"])
            seenSpaceIds.insert(spaceId)
            if spaceId == "personal" {
                return (200, """
                {"items":[\(Self.calendarItemJSON(id: "later", spaceId: "personal", title: "Later", allDay: true, startDate: "2026-05-20", startAt: nil))],"next_cursor":null}
                """)
            }
            return (200, """
            {"items":[\(Self.calendarItemJSON(id: "earlier", spaceId: "company", title: "Earlier", allDay: true, startDate: "2026-05-18", startAt: nil))],"next_cursor":null}
            """)
        })
        let repository = CalendarRepository(api: client)

        let items = try await repository.merged(
            personalSpaceId: "personal",
            companySpaceId: "company",
            fromDate: "2026-05-01",
            toDate: "2026-05-31"
        )

        XCTAssertEqual(seenSpaceIds, ["personal", "company"])
        XCTAssertEqual(items.map(\.id), ["earlier", "later"])
    }

    func testAgentRepositoryEncodesExecuteAndConfirmRequests() async throws {
        var seenPaths: [String] = []
        let client = APIClient(baseURL: URL(string: "http://unit.test/api/v1")!, authMode: .cloudJWT, tokenStore: InMemoryTokenStore(accessToken: "token"), session: Self.stubSession { request in
            seenPaths.append(request.url?.path ?? "")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
            let body = try Self.jsonBody(from: request)
            if request.url?.path == "/api/v1/agent/commands" {
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(body["command"] as? String, "create_task")
                XCTAssertEqual(body["dry_run"] as? Bool, true)
                let arguments = try XCTUnwrap(body["arguments"] as? [String: Any])
                XCTAssertEqual(arguments["title"] as? String, "Draft")
                return (200, #"{"status":"dry_run","result":null,"would_execute":{"command":"create_task"},"reason":null,"confirmation_token":null}"#)
            }
            XCTAssertEqual(request.url?.path, "/api/v1/agent/commands/confirm")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(body["confirmation_token"] as? String, "confirm-token")
            return (200, #"{"status":"success","result":{"type":"task","id":"task-1"},"would_execute":null,"reason":null,"confirmation_token":null}"#)
        })
        let repository = AgentRepository(api: client)

        let dryRun = try await repository.execute(
            command: "create_task",
            arguments: ["title": .string("Draft")],
            dryRun: true
        )
        let confirmed = try await repository.confirm(token: "confirm-token")

        XCTAssertEqual(dryRun.status, "dry_run")
        XCTAssertEqual(confirmed.result?["id"], .string("task-1"))
        XCTAssertEqual(seenPaths, ["/api/v1/agent/commands", "/api/v1/agent/commands/confirm"])
    }

    func testCaptureParserParsesChineseCalendarInput() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let now = Date(timeIntervalSince1970: 1_779_033_600) // 2026-05-18 00:00:00 +08

        let intent = try XCTUnwrap(CaptureParser.parse("明天下午3点公司会议 对账", now: now, calendar: calendar))

        XCTAssertEqual(intent.target, .fixedCalendar)
        XCTAssertEqual(intent.calendarSpace, .company)
        XCTAssertEqual(intent.allDay, false)
        XCTAssertEqual(intent.title, "对账")
        XCTAssertNotNil(intent.startAt)
    }

    func testCaptureParserParsesTaskNoteAndProject() throws {
        XCTAssertEqual(CaptureParser.parse("公司待办 跟进发票")?.target, .companyTask)
        XCTAssertEqual(CaptureParser.parse("灵感 旅行清单")?.target, .personalNote)
        XCTAssertEqual(CaptureParser.parse("新建项目 100J 发布")?.target, .companyProject)
    }

    func testAgentConfirmationPromptUsesStructuredStateAndHidesTokenFromSummary() throws {
        let draft = AgentCommandDraft(
            intent: ParsedCaptureIntent(target: .companyProject, title: "发布准备"),
            command: "archive_project",
            arguments: ["project_id": .string("project-1")],
            summary: "归档公司项目：发布准备"
        )
        let response = AgentCommandResponse(
            status: "requires_confirmation",
            result: nil,
            wouldExecute: nil,
            reason: "This action will archive an entire project.",
            confirmationToken: "secret-token"
        )

        let prompt = try XCTUnwrap(AgentConfirmationPrompt(response: response, draft: draft))

        XCTAssertEqual(prompt.token, "secret-token")
        XCTAssertEqual(prompt.reason, "This action will archive an entire project.")
        XCTAssertEqual(prompt.summary, "归档公司项目：发布准备")
        XCTAssertFalse(prompt.summary.contains("secret-token"))
    }

    func testCompanyTaskScopeMapsToQueries() {
        XCTAssertEqual(
            CompanyTaskScope.all.query(companySpaceId: "company", status: .active),
            TaskListQuery(spaceId: "company", status: .active)
        )
        XCTAssertEqual(
            CompanyTaskScope.noProject.query(companySpaceId: "company", status: .done),
            TaskListQuery(spaceId: "company", projectScope: "no_project", status: .done)
        )
        XCTAssertEqual(
            CompanyTaskScope.withProject.query(companySpaceId: "company", status: .archived, search: "tax"),
            TaskListQuery(spaceId: "company", projectScope: "with_project", status: .archived, search: "tax")
        )
        XCTAssertEqual(
            CompanyTaskScope.project("project-1").query(companySpaceId: "company", status: .active),
            TaskListQuery(projectId: "project-1", status: .active)
        )
    }

    func testPersonalTaskQueryNeverIncludesProject() {
        let query = PersonalTasksViewState.query(personalSpaceId: "personal", status: .active, search: "receipt")

        XCTAssertEqual(query.spaceId, "personal")
        XCTAssertNil(query.projectId)
        XCTAssertNil(query.projectScope)
        XCTAssertEqual(query.status, .active)
        XCTAssertEqual(query.search, "receipt")
    }

    func testCompanyWorkbenchSeparatesNoProjectAndProjectTasks() {
        let project = makeProject(id: "project-1", name: "Release")
        let looseTask = makeTask(id: "task-1", spaceId: "company", projectId: nil, title: "Follow invoice")
        let projectTask = makeTask(id: "task-2", spaceId: "company", projectId: "project-1", title: "Ship build")

        let lanes = CompanyWorkbenchViewState.lanes(projects: [project], tasks: [looseTask, projectTask])

        XCTAssertEqual(lanes.count, 2)
        XCTAssertEqual(lanes[0].id, "no_project")
        XCTAssertTrue(lanes[0].isInbox)
        XCTAssertEqual(lanes[0].tasks.map(\.id), ["task-1"])
        XCTAssertEqual(lanes[1].id, "project-1")
        XCTAssertFalse(lanes[1].isInbox)
        XCTAssertEqual(lanes[1].tasks.map(\.id), ["task-2"])
    }

    func testCalendarScopeMapsToSharedQueries() {
        XCTAssertEqual(
            CalendarViewState.query(
                filter: .all,
                selectedProjectId: nil,
                personalSpaceId: "personal",
                companySpaceId: "company"
            ),
            .all(personalSpaceId: "personal", companySpaceId: "company")
        )
        XCTAssertEqual(
            CalendarViewState.query(
                filter: .personal,
                selectedProjectId: nil,
                personalSpaceId: "personal",
                companySpaceId: "company"
            ),
            .personal(spaceId: "personal")
        )
        XCTAssertNil(
            CalendarViewState.query(
                filter: .project,
                selectedProjectId: nil,
                personalSpaceId: "personal",
                companySpaceId: "company"
            )
        )
        XCTAssertEqual(
            CalendarViewState.query(
                filter: .project,
                selectedProjectId: "project-1",
                personalSpaceId: "personal",
                companySpaceId: "company"
            ),
            .project(companySpaceId: "company", projectId: "project-1")
        )
    }

    func testCalendarViewStateSortsAndGroupsItemsByDay() {
        let date = Date(timeIntervalSince1970: 1_779_033_600)
        let allDay = makeCalendarItem(
            id: "calendar-1",
            spaceId: "personal",
            title: "All day",
            allDay: true,
            startDate: "2026-05-18",
            startAt: nil
        )
        let timed = makeCalendarItem(
            id: "calendar-2",
            spaceId: "company",
            title: "Timed",
            allDay: false,
            startDate: nil,
            startAt: date.addingTimeInterval(3_600)
        )
        let otherDay = makeCalendarItem(
            id: "calendar-3",
            spaceId: "company",
            title: "Tomorrow",
            allDay: true,
            startDate: "2026-05-19",
            startAt: nil
        )

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let items = CalendarViewState.items(on: date, from: [otherDay, timed, allDay], calendar: calendar)

        XCTAssertEqual(items.map(\.id), ["calendar-1", "calendar-2"])
        XCTAssertEqual(CalendarViewState.sortedItems([otherDay, timed, allDay]).map(\.id), ["calendar-1", "calendar-2", "calendar-3"])
    }

    func testCalendarDraftBuildsCreateAndUpdateRequests() throws {
        let date = try XCTUnwrap(CalendarViewState.parsedDateOnly("2026-05-18"))
        let draft = CalendarDraftState(
            spaceType: .company,
            title: "Board review",
            description: "  Prepare agenda  ",
            type: .appointment,
            allDay: true,
            startDate: date,
            recurrence: .monthly,
            projectId: "project-1"
        )

        let create = draft.createRequest(spaceId: "company", timezone: "Asia/Shanghai")
        XCTAssertEqual(create.spaceId, "company")
        XCTAssertEqual(create.description, "Prepare agenda")
        XCTAssertEqual(create.startDate, "2026-05-18")
        XCTAssertNil(create.startAt)
        XCTAssertEqual(create.projectId, "project-1")

        let update = draft.updateRequest(timezone: "Asia/Shanghai")
        XCTAssertEqual(update.description, "Prepare agenda")
        XCTAssertEqual(update.startDate, "2026-05-18")
        XCTAssertNil(update.startAt)
        XCTAssertEqual(update.projectId, "project-1")
    }

    private func makeTask(
        id: String,
        spaceId: String,
        projectId: String?,
        title: String,
        status: TaskStatus = .active,
        priority: TaskPriority = .medium
    ) -> TaskItem {
        let date = Date(timeIntervalSince1970: 1_779_033_600)
        return TaskItem(
            id: id,
            userId: "user-1",
            spaceId: spaceId,
            projectId: projectId,
            title: title,
            description: nil,
            status: status,
            priority: priority,
            dueDate: nil,
            remindAt: nil,
            estimatedMinutes: nil,
            source: "manual",
            completedAt: nil,
            archivedAt: nil,
            createdAt: date,
            updatedAt: date,
            version: 1
        )
    }

    private func makeCalendarItem(
        id: String,
        spaceId: String,
        title: String,
        allDay: Bool,
        startDate: String?,
        startAt: Date?
    ) -> CalendarItem {
        let date = Date(timeIntervalSince1970: 1_779_033_600)
        return CalendarItem(
            id: id,
            userId: "user-1",
            spaceId: spaceId,
            projectId: nil,
            relatedTaskId: nil,
            title: title,
            description: nil,
            type: .appointment,
            allDay: allDay,
            startDate: startDate,
            endDate: nil,
            startAt: startAt,
            endAt: nil,
            timezone: "Asia/Shanghai",
            recurrence: Recurrence.none,
            remindAt: nil,
            source: "manual",
            createdAt: date,
            updatedAt: date,
            version: 1
        )
    }

    private func makeProject(id: String, name: String) -> Project {
        let date = Date(timeIntervalSince1970: 1_779_033_600)
        return Project(
            id: id,
            userId: "user-1",
            spaceId: "company",
            name: name,
            description: nil,
            status: .active,
            startDate: nil,
            targetDate: nil,
            completedAt: nil,
            archivedAt: nil,
            createdAt: date,
            updatedAt: date,
            version: 1
        )
    }

    private static func stubSession(
        handler: @escaping (URLRequest) throws -> (Int, String)
    ) -> URLSession {
        StubURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func queryItems(from request: URLRequest) -> [String: String] {
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.value.map { (item.name, $0) }
        })
    }

    private static func jsonBody(from request: URLRequest) throws -> [String: Any] {
        let data: Data
        if let httpBody = request.httpBody {
            data = httpBody
        } else {
            let stream = try XCTUnwrap(request.httpBodyStream)
            data = readAllData(from: stream)
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

    private static func calendarItemJSON(
        id: String,
        spaceId: String,
        title: String,
        allDay: Bool,
        startDate: String?,
        startAt: String?
    ) -> String {
        """
        {
          "id":"\(id)",
          "user_id":"user-1",
          "space_id":"\(spaceId)",
          "project_id":null,
          "related_task_id":null,
          "title":"\(title)",
          "description":null,
          "type":"appointment",
          "all_day":\(allDay ? "true" : "false"),
          "start_date":\(startDate.map { "\"\($0)\"" } ?? "null"),
          "end_date":null,
          "start_at":\(startAt.map { "\"\($0)\"" } ?? "null"),
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

private final class StubURLProtocol: URLProtocol {
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
