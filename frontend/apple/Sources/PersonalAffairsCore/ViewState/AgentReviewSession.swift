import Foundation

public struct AgentReviewSession: Equatable {
    public var inputText: String
    public var pendingCommand: AgentCommandDraft?
    public var pendingConfirmation: AgentConfirmationPrompt?
    /// Whether the confirmation sheet should be presented. v1.2.4 P5-2 (#32):
    /// dismissing the sheet now leaves ``pendingConfirmation`` in place so the
    /// AgentScreen banner can re-open it; this flag controls visibility only.
    public var showConfirmationSheet: Bool
    public var responseText: String

    public init(
        inputText: String = "",
        pendingCommand: AgentCommandDraft? = nil,
        pendingConfirmation: AgentConfirmationPrompt? = nil,
        showConfirmationSheet: Bool = false,
        responseText: String = ""
    ) {
        self.inputText = inputText
        self.pendingCommand = pendingCommand
        self.pendingConfirmation = pendingConfirmation
        self.showConfirmationSheet = showConfirmationSheet
        self.responseText = responseText
    }

    public var canCompose: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var canExecute: Bool {
        pendingCommand != nil
    }

    public enum ComposeOutcome {
        case ready(AgentCommandDraft)
        case unparseable
        case missingSpaces
    }

    public mutating func consumeInput() -> String? {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        inputText = ""
        return text
    }

    public mutating func compose(text: String, personalSpace: Space?, companySpace: Space?) -> ComposeOutcome {
        guard let intent = CaptureParser.parse(text) else {
            pendingCommand = nil
            pendingConfirmation = nil
            showConfirmationSheet = false
            responseText = "我没看懂这句话。可以试试“公司待办 跟进发票”或“明天下午3点公司会议”。"
            return .unparseable
        }
        guard let draft = AgentNaturalCommandBuilder.build(
            intent: intent,
            personalSpace: personalSpace,
            companySpace: companySpace
        ) else {
            pendingCommand = nil
            pendingConfirmation = nil
            showConfirmationSheet = false
            responseText = "当前空间还没加载完成。请先刷新数据，再试一次。"
            return .missingSpaces
        }
        pendingCommand = draft
        pendingConfirmation = nil
        showConfirmationSheet = false
        responseText = "已生成可审核操作。"
        return .ready(draft)
    }

    public mutating func apply(response: AgentCommandResponse, dryRun: Bool) {
        responseText = AgentReviewSession.render(response: response)
        if let prompt = AgentConfirmationPrompt(response: response, draft: pendingCommand) {
            pendingConfirmation = prompt
            // Auto-present the sheet for newly arrived confirmation prompts.
            // The user can dismiss it; the banner on AgentScreen will then
            // re-open via ``showConfirmationSheet`` without losing the prompt.
            showConfirmationSheet = true
        } else if !dryRun {
            pendingCommand = nil
            pendingConfirmation = nil
            showConfirmationSheet = false
        }
    }

    public mutating func cancel() {
        pendingCommand = nil
        pendingConfirmation = nil
        showConfirmationSheet = false
        responseText = "已取消这次操作。"
    }

    public static func render(response: AgentCommandResponse) -> String {
        var lines = ["状态：\(response.status)"]
        if let reason = response.reason {
            lines.append("原因：\(reason)")
        }
        if let result = response.result {
            lines.append("结果：\(result)")
        }
        if let wouldExecute = response.wouldExecute {
            lines.append("预演：\(wouldExecute)")
        }
        return lines.joined(separator: "\n")
    }
}
