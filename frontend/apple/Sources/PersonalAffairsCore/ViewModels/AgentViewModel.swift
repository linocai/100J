import Combine
import Foundation

@MainActor
public final class AgentViewModel: ObservableObject {
    @Published public private(set) var tools: [AgentTool] = []
    @Published public private(set) var logs: [AgentActionLog] = []
    @Published public private(set) var llmKey: LLMKey?
    @Published public var review = AgentReviewSession()
    @Published public private(set) var loading = false
    @Published public private(set) var lastError: APIClientError?

    private let repo: AgentRepository
    private let personalSpace: () -> Space?
    private let companySpace: () -> Space?

    public init(
        repo: AgentRepository,
        personalSpace: @escaping () -> Space?,
        companySpace: @escaping () -> Space?
    ) {
        self.repo = repo
        self.personalSpace = personalSpace
        self.companySpace = companySpace
    }

    public var pendingConfirmation: AgentConfirmationPrompt? {
        review.pendingConfirmation
    }

    public func reloadSupport() async {
        loading = true
        defer { loading = false }
        do {
            tools = try await repo.tools()
            logs = try await repo.logs()
            llmKey = try await repo.llmKey()
            lastError = nil
        } catch {
            lastError = viewModelError(from: error)
        }
    }

    public func saveLLMKey(provider: String, apiKey: String) async {
        loading = true
        defer { loading = false }
        do {
            llmKey = try await repo.saveLLMKey(provider: provider, apiKey: apiKey)
            lastError = nil
        } catch {
            lastError = viewModelError(from: error)
        }
    }

    public func composePendingInput() {
        guard let text = review.consumeInput() else { return }
        _ = review.compose(text: text, personalSpace: personalSpace(), companySpace: companySpace())
    }

    public func execute(dryRun: Bool) async {
        guard let command = review.pendingCommand else { return }
        loading = true
        defer { loading = false }
        do {
            let response = try await repo.execute(
                command: command.command,
                arguments: command.arguments,
                dryRun: dryRun
            )
            review.apply(response: response, dryRun: dryRun)
            lastError = nil
        } catch {
            lastError = viewModelError(from: error)
        }
    }

    public func confirm() async {
        guard let prompt = review.pendingConfirmation else { return }
        loading = true
        defer { loading = false }
        do {
            let response = try await repo.confirm(token: prompt.token)
            review.apply(response: response, dryRun: false)
            lastError = nil
        } catch {
            lastError = viewModelError(from: error)
        }
    }

    public func cancel() {
        review.cancel()
    }
}
