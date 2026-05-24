#if canImport(AppIntents)
import AppIntents
import Foundation
import PersonalAffairsCore

@available(iOS 16.0, macOS 13.0, *)
struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "新建待办"
    static var description = IntentDescription("用一句话在 100J 中创建个人或公司待办。")
    static var openAppWhenRun = false

    @Parameter(title: "内容")
    var content: String

    init() {
        self.content = ""
    }

    init(content: String) {
        self.content = content
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary = try await AppIntentCommandRunner.createTask(from: content)
        return .result(dialog: IntentDialog(stringLiteral: summary))
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct AskAgentIntent: AppIntent {
    static var title: LocalizedStringResource = "询问 Agent"
    static var description = IntentDescription("让 100J Agent 预演一条可审核操作。")
    static var openAppWhenRun = false

    @Parameter(title: "问题")
    var question: String

    init() {
        self.question = ""
    }

    init(question: String) {
        self.question = question
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let response = try await AppIntentCommandRunner.askAgent(question)
        return .result(dialog: IntentDialog(stringLiteral: response))
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct PersonalAffairsShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateTaskIntent(),
            phrases: [
                "在 \(.applicationName) 新建待办",
                "用 \(.applicationName) 记录待办"
            ],
            shortTitle: "新建待办",
            systemImageName: "checklist"
        )

        AppShortcut(
            intent: AskAgentIntent(),
            phrases: [
                "询问 \(.applicationName)",
                "让 \(.applicationName) 预演操作"
            ],
            shortTitle: "询问 Agent",
            systemImageName: "sparkles"
        )
    }
}

private enum AppIntentCommandRunner {
    static func createTask(from rawText: String) async throws -> String {
        let text = try normalized(rawText)
        let api = makeAPIClient()
        let spaces = try await SpaceRepository(api: api).list()
        let personalSpace = spaces.first { $0.type == .personal }
        let companySpace = spaces.first { $0.type == .company }
        guard let intent = taskIntent(from: text),
              let draft = AgentNaturalCommandBuilder.build(
                intent: intent,
                personalSpace: personalSpace,
                companySpace: companySpace
              ),
              draft.command == "create_task"
        else {
            throw AppIntentCommandError.unavailable("当前空间还没加载完成，或这句话不能创建待办。")
        }

        let response = try await AgentRepository(api: api).execute(
            command: draft.command,
            arguments: draft.arguments,
            dryRun: false
        )
        if response.status == "requires_confirmation" {
            return "这条待办需要打开 100J 完成二次确认。"
        }
        if response.status == "success" {
            return "已创建：\(intent.title)"
        }
        return AgentReviewSession.render(response: response)
    }

    static func askAgent(_ rawText: String) async throws -> String {
        let text = try normalized(rawText)
        let api = makeAPIClient()
        let spaces = try await SpaceRepository(api: api).list()
        guard let intent = CaptureParser.parse(text),
              let draft = AgentNaturalCommandBuilder.build(
                intent: intent,
                personalSpace: spaces.first { $0.type == .personal },
                companySpace: spaces.first { $0.type == .company }
              )
        else {
            throw AppIntentCommandError.unavailable("我还不能把这句话转成可审核操作。")
        }

        let response = try await AgentRepository(api: api).execute(
            command: draft.command,
            arguments: draft.arguments,
            dryRun: true
        )
        return AgentReviewSession.render(response: response)
    }

    private static func normalized(_ rawText: String) throws -> String {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw AppIntentCommandError.unavailable("内容不能为空。")
        }
        return text
    }

    private static func taskIntent(from text: String) -> ParsedCaptureIntent? {
        if let intent = CaptureParser.parse(text),
           intent.target == .personalTask || intent.target == .companyTask {
            return intent
        }

        let targetPrefix = text.localizedCaseInsensitiveContains("公司")
            || text.localizedCaseInsensitiveContains("工作") ? "公司待办 " : "个人待办 "
        return CaptureParser.parse(targetPrefix + text)
    }

    private static func makeAPIClient() -> APIClient {
        let defaultBaseURL = AppModel.defaultCloudBaseURL
        let storedBaseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? defaultBaseURL
        let authMode = UserDefaults.standard.string(forKey: "appAuthMode")
            .flatMap(AppAuthMode.init(rawValue:)) ?? .cloudJWT
        return APIClient(
            baseURL: URL(string: storedBaseURL) ?? URL(string: defaultBaseURL)!,
            authMode: authMode
        )
    }
}

private enum AppIntentCommandError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message): return message
        }
    }
}
#endif
