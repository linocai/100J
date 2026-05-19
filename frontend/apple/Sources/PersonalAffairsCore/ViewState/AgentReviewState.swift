import Foundation

public struct AgentCommandDraft: Equatable {
    public let intent: ParsedCaptureIntent
    public let command: String
    public let arguments: [String: JSONValue]
    public let summary: String

    public init(
        intent: ParsedCaptureIntent,
        command: String,
        arguments: [String: JSONValue],
        summary: String
    ) {
        self.intent = intent
        self.command = command
        self.arguments = arguments
        self.summary = summary
    }
}

public struct AgentConfirmationPrompt: Identifiable, Equatable {
    public var id: String { token }
    public let token: String
    public let reason: String
    public let summary: String
    public let command: String

    public init(token: String, reason: String, summary: String, command: String) {
        self.token = token
        self.reason = reason
        self.summary = summary
        self.command = command
    }

    public init?(response: AgentCommandResponse, draft: AgentCommandDraft?) {
        guard response.status == "requires_confirmation",
              let token = response.confirmationToken
        else {
            return nil
        }
        self.token = token
        self.reason = response.reason ?? "这条操作需要二次确认。"
        self.summary = draft?.summary ?? "确认执行 Agent 操作"
        self.command = draft?.command ?? "agent_command"
    }
}

public enum AgentNaturalCommandBuilder {
    public static func build(
        intent: ParsedCaptureIntent,
        personalSpace: Space?,
        companySpace: Space?,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> AgentCommandDraft? {
        switch intent.target {
        case .personalTask:
            guard let space = personalSpace else { return nil }
            return AgentCommandDraft(
                intent: intent,
                command: "create_task",
                arguments: baseTaskArguments(spaceId: space.id, intent: intent),
                summary: "创建个人待办：\(intent.title)"
            )
        case .companyTask:
            guard let space = companySpace else { return nil }
            return AgentCommandDraft(
                intent: intent,
                command: "create_task",
                arguments: baseTaskArguments(spaceId: space.id, intent: intent),
                summary: "创建公司待办：\(intent.title)"
            )
        case .fixedCalendar:
            let targetSpace = intent.calendarSpace == .personal ? personalSpace : companySpace
            guard let space = targetSpace else { return nil }
            var arguments: [String: JSONValue] = [
                "space_id": .string(space.id),
                "title": .string(intent.title),
                "description": .string(intent.description ?? intent.title),
                "type": .string(intent.calendarType.rawValue),
                "all_day": .bool(intent.allDay),
                "timezone": .string(timeZone.identifier),
                "recurrence": .string(intent.recurrence.rawValue)
            ]
            if intent.allDay {
                arguments["start_date"] = .string(intent.startDate ?? dayKey(now))
            } else if let startAt = intent.startAt {
                arguments["start_at"] = .string(isoFormatter.string(from: startAt))
            }
            return AgentCommandDraft(
                intent: intent,
                command: "create_calendar_item",
                arguments: arguments,
                summary: "创建\(intent.calendarSpace.label)固定日程：\(intent.title)"
            )
        case .personalNote:
            guard let space = personalSpace else { return nil }
            return AgentCommandDraft(
                intent: intent,
                command: "create_note",
                arguments: [
                    "space_id": .string(space.id),
                    "title": .string(intent.title),
                    "body": .string(intent.description ?? intent.title),
                    "type": .string(intent.noteType.rawValue)
                ],
                summary: "创建个人备忘：\(intent.title)"
            )
        case .companyProject:
            guard let space = companySpace else { return nil }
            return AgentCommandDraft(
                intent: intent,
                command: "create_project",
                arguments: [
                    "space_id": .string(space.id),
                    "name": .string(intent.title),
                    "description": .string(intent.description ?? "")
                ],
                summary: "创建公司项目：\(intent.title)"
            )
        }
    }

    private static func baseTaskArguments(spaceId: String, intent: ParsedCaptureIntent) -> [String: JSONValue] {
        var arguments: [String: JSONValue] = [
            "space_id": .string(spaceId),
            "title": .string(intent.title),
            "priority": .string(intent.priority.rawValue)
        ]
        if let description = intent.description {
            arguments["description"] = .string(description)
        }
        if let dueDate = intent.dueDate {
            arguments["due_date"] = .string(dueDate)
        }
        return arguments
    }

    private static func dayKey(_ date: Date) -> String {
        dateOnlyFormatter.string(from: date)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

public extension ParsedCaptureTarget {
    var label: String {
        switch self {
        case .personalTask: return "个人待办"
        case .companyTask: return "公司待办"
        case .fixedCalendar: return "固定日程"
        case .personalNote: return "个人备忘"
        case .companyProject: return "公司项目"
        }
    }
}

