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
}
