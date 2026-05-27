#if canImport(AppIntents)
import AppIntents
import Foundation
import PersonalAffairsCore

/// v1.2.4.2 (P1-8): the Siri / Spotlight shortcut for "新建待办" now writes
/// directly through `TaskRepository` instead of going through the deleted
/// CaptureParser + Agent pipeline. The old `AskAgentIntent` (which was a
/// thin wrapper around the now-deleted natural-language Agent dry-run
/// path) is removed — there is no replacement, because the dedicated
/// Agent tab inside the app still offers that flow and is the supported
/// surface for ambiguous commands.
@available(iOS 16.0, macOS 13.0, *)
struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "新建待办"
    static var description = IntentDescription("用一句话在 100J 中创建个人或公司待办。")
    static var openAppWhenRun = false

    @Parameter(title: "内容")
    var content: String

    /// Optional classification — when omitted we infer from the content
    /// (Chinese keywords for 公司 / 工作 → company; otherwise personal).
    @Parameter(title: "归属", default: TaskScopeOption.personal)
    var scope: TaskScopeOption

    init() {
        self.content = ""
        self.scope = .personal
    }

    init(content: String, scope: TaskScopeOption = .personal) {
        self.content = content
        self.scope = scope
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary = try await AppIntentCommandRunner.createTask(
            from: content,
            scope: scope
        )
        return .result(dialog: IntentDialog(stringLiteral: summary))
    }
}

@available(iOS 16.0, macOS 13.0, *)
enum TaskScopeOption: String, AppEnum {
    case personal
    case company

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "归属"

    static var caseDisplayRepresentations: [TaskScopeOption: DisplayRepresentation] = [
        .personal: "个人",
        .company: "公司"
    ]
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
    }
}

private enum AppIntentCommandRunner {
    static func createTask(from rawText: String, scope: TaskScopeOption) async throws -> String {
        let title = try normalized(rawText)
        let api = makeAPIClient()
        let spaces = try await SpaceRepository(api: api).list()
        let resolvedScope: TaskScopeOption = scope == .personal
            ? inferScope(from: title) ?? .personal
            : scope
        let targetSpace = resolvedScope == .company
            ? spaces.first { $0.type == .company }
            : spaces.first { $0.type == .personal }
        guard let space = targetSpace else {
            throw AppIntentCommandError.unavailable("当前空间还没加载完成，请打开 100J 后再试。")
        }

        let request = TaskCreateRequest(spaceId: space.id, title: title)
        _ = try await TaskRepository(api: api).create(request)
        return resolvedScope == .company
            ? "已创建公司待办：\(title)"
            : "已创建个人待办：\(title)"
    }

    /// Lightweight scope inference for the shortcut. Detects 公司 / 工作
    /// hints in the dictation so "Siri，用 100J 记下 公司开会" still routes
    /// to the company space without forcing the user to pick from the
    /// parameter sheet every time.
    private static func inferScope(from text: String) -> TaskScopeOption? {
        if text.localizedCaseInsensitiveContains("公司")
            || text.localizedCaseInsensitiveContains("工作") {
            return .company
        }
        return nil
    }

    private static func normalized(_ rawText: String) throws -> String {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw AppIntentCommandError.unavailable("内容不能为空。")
        }
        return text
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
