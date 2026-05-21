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

    public func ownerLogin(accessCode: String) async throws -> TokenResponse {
        let tokens: TokenResponse = try await api.send(
            "/auth/owner-login",
            method: .post,
            body: OwnerLoginRequest(accessCode: accessCode),
            response: TokenResponse.self
        )
        try api.tokenStore.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
        return tokens
    }

    public func signInWithApple(idToken: String, email: String?, fullName: String?, bundleId: String) async throws -> TokenResponse {
        let tokens: TokenResponse = try await api.send(
            "/auth/apple",
            method: .post,
            body: AppleSignInRequest(idToken: idToken, bundleId: bundleId, email: email, fullName: fullName),
            response: TokenResponse.self
        )
        try api.tokenStore.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
        return tokens
    }

    public func requestEmailOTP(email: String) async throws {
        _ = try await api.send(
            "/auth/email-otp/request",
            method: .post,
            body: EmailRequest(email: email),
            response: EmptyResponse.self
        )
    }

    public func verifyEmailOTP(email: String, code: String) async throws -> TokenResponse {
        let tokens: TokenResponse = try await api.send(
            "/auth/email-otp/verify",
            method: .post,
            body: EmailOTPVerifyRequest(email: email, code: code),
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

    public func seedDemo() async throws -> SeedDemoResponse {
        try await api.send(
            "/me/seed-demo",
            method: .post,
            response: SeedDemoResponse.self
        )
    }
}
