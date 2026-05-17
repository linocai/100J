import Foundation

public final class AuthRepository {
    private let api: APIClient

    public init(api: APIClient) {
        self.api = api
    }

    public func register(email: String, password: String, displayName: String?) async throws -> TokenResponse {
        let tokens: TokenResponse = try await api.send(
            "/auth/register",
            method: .post,
            body: RegisterRequest(email: email, password: password, displayName: displayName),
            response: TokenResponse.self
        )
        try api.tokenStore.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
        return tokens
    }

    public func login(email: String, password: String) async throws -> TokenResponse {
        let tokens: TokenResponse = try await api.send(
            "/auth/login",
            method: .post,
            body: LoginRequest(email: email, password: password),
            response: TokenResponse.self
        )
        try api.tokenStore.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
        return tokens
    }

    public func logout() async throws {
        _ = try? await api.send("/auth/logout", method: .post, response: EmptyResponse.self)
        try api.tokenStore.clear()
    }

    public func me() async throws -> User {
        try await api.send("/me", response: User.self)
    }
}

