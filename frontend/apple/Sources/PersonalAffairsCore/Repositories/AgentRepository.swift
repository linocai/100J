import Foundation

public final class AgentRepository {
    private let api: APIClient

    public init(api: APIClient) {
        self.api = api
    }

    public func llmKey() async throws -> LLMKey {
        try await api.send("/agent/llm-key", response: LLMKey.self)
    }

    public func saveLLMKey(provider: String, apiKey: String) async throws -> LLMKey {
        try await api.send(
            "/agent/llm-key",
            method: .put,
            body: LLMKeyRequest(provider: provider, apiKey: apiKey),
            response: LLMKey.self
        )
    }

    public func deleteLLMKey() async throws {
        _ = try await api.send("/agent/llm-key", method: .delete, response: EmptyResponse.self)
    }

    public func tools() async throws -> [AgentTool] {
        let response: AgentToolsResponse = try await api.send("/agent/tools", response: AgentToolsResponse.self)
        return response.tools
    }

    public func execute(command: String, arguments: [String: JSONValue], dryRun: Bool) async throws -> AgentCommandResponse {
        try await api.send(
            "/agent/commands",
            method: .post,
            body: AgentCommandRequest(command: command, arguments: arguments, dryRun: dryRun),
            response: AgentCommandResponse.self
        )
    }

    public func confirm(token: String) async throws -> AgentCommandResponse {
        try await api.send(
            "/agent/commands/confirm",
            method: .post,
            body: AgentConfirmRequest(confirmationToken: token),
            response: AgentCommandResponse.self
        )
    }

    public func logs() async throws -> [AgentActionLog] {
        let response: PageResponse<AgentActionLog> = try await api.send(
            "/agent/action-logs",
            response: PageResponse<AgentActionLog>.self
        )
        return response.items
    }
}

