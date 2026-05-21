import Combine
import Foundation

public struct ComposerSuggestion: Identifiable, Equatable {
    public let id: String
    public let label: String
    public let hint: String

    public init(id: String, label: String, hint: String) {
        self.id = id
        self.label = label
        self.hint = hint
    }
}

@MainActor
public final class UniversalComposerViewModel: ObservableObject {
    @Published public var input: String = ""
    @Published public private(set) var pendingDraft: AgentCommandDraft?
    @Published public private(set) var suggestions: [ComposerSuggestion] = [
        ComposerSuggestion(id: "task", label: "新建任务", hint: "Enter"),
        ComposerSuggestion(id: "note", label: "记一条灵感", hint: "↓"),
        ComposerSuggestion(id: "calendar", label: "新建日程", hint: "↓"),
        ComposerSuggestion(id: "agent", label: "让 Agent 整理 Inbox", hint: "↓")
    ]

    private let personalSpace: () -> Space?
    private let companySpace: () -> Space?

    public init(personalSpace: @escaping () -> Space?, companySpace: @escaping () -> Space?) {
        self.personalSpace = personalSpace
        self.companySpace = companySpace
    }

    @discardableResult
    public func parse() -> AgentCommandDraft? {
        guard let intent = CaptureParser.parse(input) else {
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
}
