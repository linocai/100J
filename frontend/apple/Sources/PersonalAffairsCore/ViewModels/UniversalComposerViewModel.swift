import Combine
import Foundation

public struct ComposerSuggestion: Identifiable, Equatable {
    public let id: String
    public let label: String
    public let hint: String
    public let systemImage: String

    public init(id: String, label: String, hint: String, systemImage: String) {
        self.id = id
        self.label = label
        self.hint = hint
        self.systemImage = systemImage
    }
}

@MainActor
public final class UniversalComposerViewModel: ObservableObject {
    @Published public var input: String = ""
    @Published public var isOpen = false
    @Published public private(set) var pendingDraft: AgentCommandDraft?
    @Published public private(set) var suggestions: [ComposerSuggestion] = [
        ComposerSuggestion(id: "task", label: "新建任务", hint: "/task", systemImage: "checklist"),
        ComposerSuggestion(id: "note", label: "记一条灵感", hint: "/note", systemImage: "note.text"),
        ComposerSuggestion(id: "calendar", label: "新建日程", hint: "/event", systemImage: "calendar.badge.plus"),
        ComposerSuggestion(id: "agent", label: "让 Agent 整理 Inbox", hint: "/agent", systemImage: "sparkles")
    ]

    private let personalSpace: () -> Space?
    private let companySpace: () -> Space?

    public init(personalSpace: @escaping () -> Space?, companySpace: @escaping () -> Space?) {
        self.personalSpace = personalSpace
        self.companySpace = companySpace
    }

    public func open(prefill: String = "") {
        if !prefill.isEmpty {
            input = prefill
        }
        isOpen = true
    }

    public func close() {
        isOpen = false
    }

    @discardableResult
    public func submit() async -> AgentCommandDraft? {
        parse()
    }

    @discardableResult
    public func pick(_ suggestion: ComposerSuggestion) async -> AgentCommandDraft? {
        switch suggestion.id {
        case "task":
            input = input.nilIfBlank ?? "个人待办 "
        case "note":
            input = input.nilIfBlank ?? "灵感 "
        case "calendar":
            input = input.nilIfBlank ?? "固定日程 "
        case "agent":
            input = input.nilIfBlank ?? "Agent 整理 "
        default:
            break
        }
        return parse()
    }

    @discardableResult
    public func parse() -> AgentCommandDraft? {
        guard let intent = CaptureParser.parse(normalizedInput()) else {
            pendingDraft = nil
            return nil
        }
        pendingDraft = AgentNaturalCommandBuilder.build(
            intent: intent,
            personalSpace: personalSpace(),
            companySpace: companySpace()
        )
        return pendingDraft
    }

    public func clear() {
        input = ""
        pendingDraft = nil
    }

    private func normalizedInput() -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let prefixMap: [(prefix: String, replacement: String)] = [
            ("/task", "个人待办 "),
            ("/note", "灵感 "),
            ("/event", "固定日程 "),
            ("/calendar", "固定日程 "),
            ("/agent", "")
        ]
        for item in prefixMap where lower.hasPrefix(item.prefix) {
            let rest = String(trimmed.dropFirst(item.prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return item.replacement + rest
        }
        return trimmed
    }
}
