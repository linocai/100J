import Foundation

/// `open` so unit tests can subclass it with stubbed `silentResume()` /
/// `me()` methods without needing a network. Production code never
/// subclasses.
open class AuthRepository {
    private let api: APIClient
    private let deviceSession: DeviceSessionStore

    public init(api: APIClient, deviceSession: DeviceSessionStore = .shared) {
        self.api = api
        self.deviceSession = deviceSession
    }

    public func register(email: String, password: String, displayName: String?) async throws -> TokenResponse {
        let tokens: TokenResponse = try await api.send(
            "/auth/register",
            method: .post,
            body: RegisterRequest(email: email, password: password, displayName: displayName),
            response: TokenResponse.self
        )
        try persist(tokens)
        return tokens
    }

    public func login(email: String, password: String) async throws -> TokenResponse {
        let tokens: TokenResponse = try await api.send(
            "/auth/login",
            method: .post,
            body: LoginRequest(email: email, password: password),
            response: TokenResponse.self
        )
        try persist(tokens)
        return tokens
    }

    /// 一次性输入访问码即可换取 device-bound session；之后再不需要密码。
    public func ownerLogin(accessCode: String) async throws -> TokenResponse {
        let tokens: TokenResponse = try await api.send(
            "/auth/owner-login",
            method: .post,
            body: OwnerLoginRequest(
                accessCode: accessCode,
                deviceId: deviceSession.deviceId,
                deviceName: DeviceSessionStore.defaultDeviceName,
                platform: DeviceSessionStore.defaultPlatform
            ),
            response: TokenResponse.self
        )
        try persist(tokens)
        return tokens
    }

    @available(*, deprecated, message: "v1.2.4: feature gated off; backend returns 404. Re-enable in v1.3.0.")
    public func signInWithApple(idToken: String, email: String?, fullName: String?, bundleId: String) async throws -> TokenResponse {
        let tokens: TokenResponse = try await api.send(
            "/auth/apple",
            method: .post,
            body: AppleSignInRequest(
                idToken: idToken,
                bundleId: bundleId,
                email: email,
                fullName: fullName,
                deviceId: deviceSession.deviceId,
                deviceName: DeviceSessionStore.defaultDeviceName,
                platform: DeviceSessionStore.defaultPlatform
            ),
            response: TokenResponse.self
        )
        try persist(tokens)
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
        try persist(tokens)
        return tokens
    }

    /// 启动时调用：如果 Keychain 有 device refresh token，静默换 access token。
    /// 失败抛 APIClientError.unauthorized（调用方应回到登录页）。
    open func silentResume() async throws {
        guard let refreshToken = deviceSession.refreshToken else {
            // v1.2.4 (#1): no token in Keychain means whatever made us land
            // here (RootView ResumingPlaceholder) was a stale "hasActiveSession"
            // signal. Clear DeviceSessionStore so the next render falls
            // back to SetupScreen instead of looping in the placeholder.
            deviceSession.clearAll()
            throw APIClientError.unauthorized
        }
        do {
            let tokens: TokenResponse = try await api.send(
                "/auth/device-refresh",
                method: .post,
                body: DeviceRefreshRequest(
                    deviceId: deviceSession.deviceId,
                    refreshToken: refreshToken
                ),
                response: TokenResponse.self
            )
            try persist(tokens)
        } catch APIClientError.unauthorized {
            // Server says the device session is dead. Clear local state
            // so the placeholder can clear out and SetupScreen shows up.
            deviceSession.clearAll()
            throw APIClientError.unauthorized
        }
    }

    public func logout() async throws {
        // 优先 revoke 服务器端 device session
        if deviceSession.hasActiveSession {
            _ = try? await api.send(
                "/auth/device-logout",
                method: .post,
                body: DeviceLogoutRequest(deviceId: deviceSession.deviceId, refreshToken: deviceSession.refreshToken),
                response: EmptyResponse.self
            )
        } else {
            _ = try? await api.send("/auth/logout", method: .post, response: EmptyResponse.self)
        }
        try api.tokenStore.clear()
        deviceSession.clearAll()
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

    // MARK: - Helpers

    private func persist(_ tokens: TokenResponse) throws {
        try api.tokenStore.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
        if let deviceId = tokens.deviceId, deviceId == deviceSession.deviceId {
            // 服务器确认 device session 颁发 → refreshToken 是 device-bound 的
            try deviceSession.saveRefreshToken(tokens.refreshToken)
            deviceSession.recordIssued(
                deviceName: tokens.deviceName,
                expiresAt: tokens.expiresAt.flatMap(ISO8601DateFormatter.shared.date(from:))
            )
        }
    }
}

private extension ISO8601DateFormatter {
    static let shared: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
