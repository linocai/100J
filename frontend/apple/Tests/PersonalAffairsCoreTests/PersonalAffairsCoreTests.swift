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

    private static func stubSession(
        handler: @escaping (URLRequest) throws -> (Int, String)
    ) -> URLSession {
        StubURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
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
