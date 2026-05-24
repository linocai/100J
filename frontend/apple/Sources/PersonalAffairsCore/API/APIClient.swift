import Foundation

public enum APIClientError: Error, LocalizedError, Equatable {
    case invalidURL
    case unauthorized
    case server(code: String, message: String)
    case network(String)
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "API 地址无效。"
        case .unauthorized:
            return "登录已过期，请重新登录。"
        case .server(_, let message):
            return message
        case .network(let message):
            return message
        case .transport(let message):
            return message
        }
    }
}

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

public struct EmptyBody: Encodable {
    public init() {}
}

public struct EmptyResponse: Decodable {
    public init() {}
}

private struct ErrorEnvelope: Decodable {
    let error: APIErrorDetail
}

private struct APIErrorDetail: Decodable {
    let code: String
    let message: String
}

public final class APIClient {
    public var baseURL: URL
    public var authMode: AppAuthMode
    public let tokenStore: TokenStore
    private let deviceSession: DeviceSessionStore?

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let diagnostics: DiagnosticLogger

    /// v1.2.4 (#12): per-path cool-down so a flurry of 401s within the
    /// same window doesn't trigger expireCloudSession() twice in a row.
    private var lastUnauthorizedHandledAt: [String: Date] = [:]
    private let unauthorizedCooldown: TimeInterval = 5

    public init(
        baseURL: URL = URL(string: "http://127.0.0.1:8000/api/v1")!,
        authMode: AppAuthMode = .localOwner,
        tokenStore: TokenStore = KeychainTokenStore(),
        deviceSession: DeviceSessionStore? = .shared,
        session: URLSession = .shared,
        diagnostics: DiagnosticLogger = .shared
    ) {
        self.baseURL = baseURL
        self.authMode = authMode
        self.tokenStore = tokenStore
        self.deviceSession = deviceSession
        self.session = session
        self.diagnostics = diagnostics
        self.decoder = JSONDecoder.personalAffairs
        self.encoder = JSONEncoder.personalAffairs
    }

    public func send<Response: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        query: [URLQueryItem] = [],
        response: Response.Type = Response.self
    ) async throws -> Response {
        try await send(path, method: method, query: query, body: Optional<EmptyBody>.none, response: response)
    }

    public func send<Response: Decodable, Body: Encodable>(
        _ path: String,
        method: HTTPMethod = .get,
        query: [URLQueryItem] = [],
        body: Body?,
        response: Response.Type = Response.self
    ) async throws -> Response {
        try await send(path, method: method, query: query, body: body, response: response, allowRefresh: true)
    }

    private func send<Response: Decodable, Body: Encodable>(
        _ path: String,
        method: HTTPMethod,
        query: [URLQueryItem],
        body: Body?,
        response: Response.Type,
        allowRefresh: Bool
    ) async throws -> Response {
        let request = try makeRequest(path, method: method, query: query, body: body)
        let (data, urlResponse): (Data, URLResponse)
        do {
            (data, urlResponse) = try await session.data(for: request)
        } catch {
            diagnostics.recordAPI(method: method.rawValue, path: path, status: nil, error: "network")
            throw APIClientError.network(error.localizedDescription)
        }

        guard let http = urlResponse as? HTTPURLResponse else {
            diagnostics.recordAPI(method: method.rawValue, path: path, status: nil, error: "invalid_http_response")
            throw APIClientError.transport("HTTP 响应无效。")
        }

        if authMode == .cloudJWT,
           http.statusCode == 401,
           allowRefresh,
           shouldTreatUnauthorizedAsExpiredSession(path: path),
           try await refreshTokensIfPossible() {
            return try await send(
                path,
                method: method,
                query: query,
                body: body,
                response: response,
                allowRefresh: false
            )
        }

        guard (200..<300).contains(http.statusCode) else {
            if let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) {
                if envelope.error.code == "unauthorized", shouldTreatUnauthorizedAsExpiredSession(path: path) {
                    diagnostics.recordAPI(method: method.rawValue, path: path, status: http.statusCode, error: "unauthorized")
                    if shouldSuppressUnauthorizedSessionExpire(path: path) {
                        // v1.2.4 (#12): same path 401'd within the cool-down
                        // — caller already handled it once, don't nuke the
                        // token store again (which would clobber a fresh
                        // refresh that just happened in parallel).
                        throw APIClientError.unauthorized
                    }
                    rememberUnauthorized(path: path)
                    try? tokenStore.clear()
                    throw APIClientError.unauthorized
                }
                diagnostics.recordAPI(method: method.rawValue, path: path, status: http.statusCode, error: envelope.error.code)
                throw APIClientError.server(code: envelope.error.code, message: envelope.error.message)
            }
            diagnostics.recordAPI(method: method.rawValue, path: path, status: http.statusCode, error: "http_error")
            throw APIClientError.server(code: "http_error", message: "HTTP \(http.statusCode)")
        }

        diagnostics.recordAPI(method: method.rawValue, path: path, status: http.statusCode, error: nil)
        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }
        return try decoder.decode(Response.self, from: data)
    }

    private func makeRequest<Body: Encodable>(
        _ path: String,
        method: HTTPMethod,
        query: [URLQueryItem],
        body: Body?
    ) throws -> URLRequest {
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard var components = URLComponents(url: baseURL.appendingPathComponent(cleanPath), resolvingAgainstBaseURL: false) else {
            throw APIClientError.invalidURL
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIClientError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if authMode == .cloudJWT, let token = tokenStore.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }
        return request
    }

    private func refreshTokensIfPossible() async throws -> Bool {
        guard authMode == .cloudJWT else { return false }

        // v1.2.4 (#1): if this client has a device-bound refresh token,
        // prefer /auth/device-refresh — JWT-only /auth/refresh wouldn't
        // work because v1.2 backend issues access tokens via device session
        // for cloud users.
        if let deviceSession, deviceSession.hasActiveSession,
           let deviceRefreshToken = deviceSession.refreshToken {
            let body = DeviceRefreshRequest(
                deviceId: deviceSession.deviceId,
                refreshToken: deviceRefreshToken
            )
            do {
                let tokens: TokenResponse = try await send(
                    "/auth/device-refresh",
                    method: .post,
                    query: [],
                    body: body,
                    response: TokenResponse.self,
                    allowRefresh: false
                )
                try tokenStore.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
                try deviceSession.saveRefreshToken(tokens.refreshToken)
                deviceSession.recordIssued(
                    deviceName: tokens.deviceName,
                    expiresAt: tokens.expiresAt.flatMap(Self.iso8601Formatter.date(from:))
                )
                return true
            } catch {
                // fall through to JWT-only path; some legacy callers may still
                // have a /auth/refresh path open.
            }
        }

        // JWT-only fallback (legacy register / login / email-otp paths).
        // No clearing here: when refresh isn't possible / fails, we let
        // the outer 401 handler decide whether to nuke the store (it
        // respects the cooldown; we don't).
        guard let refreshToken = tokenStore.refreshToken else { return false }
        let body = RefreshRequest(refreshToken: refreshToken)
        do {
            let tokens: TokenResponse = try await send(
                "/auth/refresh",
                method: .post,
                query: [],
                body: body,
                response: TokenResponse.self,
                allowRefresh: false
            )
            try tokenStore.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
            return true
        } catch {
            return false
        }
    }

    private func shouldTreatUnauthorizedAsExpiredSession(path: String) -> Bool {
        !path.hasPrefix("/auth/")
    }

    private func shouldSuppressUnauthorizedSessionExpire(path: String) -> Bool {
        guard let last = lastUnauthorizedHandledAt[path] else { return false }
        return Date().timeIntervalSince(last) < unauthorizedCooldown
    }

    private func rememberUnauthorized(path: String) {
        lastUnauthorizedHandledAt[path] = Date()
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    public func fetchAll<Item: Codable>(
        _ path: String,
        query: [URLQueryItem] = [],
        limit: Int = 100,
        response: PageResponse<Item>.Type = PageResponse<Item>.self
    ) async throws -> [Item] {
        var items: [Item] = []
        var cursor: String?

        repeat {
            var pageQuery = query
            pageQuery.append(URLQueryItem(name: "limit", value: "\(limit)"))
            pageQuery.appendIfPresent("cursor", cursor)
            let page: PageResponse<Item> = try await send(path, query: pageQuery, response: response)
            items.append(contentsOf: page.items)
            cursor = page.nextCursor
        } while cursor != nil

        return items
    }
}

extension JSONDecoder {
    public static var personalAffairs: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = DateFormatters.iso8601WithFractional.date(from: value) {
                return date
            }
            if let date = DateFormatters.iso8601.date(from: value) {
                return date
            }
            if let date = DateFormatters.backendNaiveWithFractional.date(from: value) {
                return date
            }
            if let date = DateFormatters.backendNaive.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date \(value)")
        }
        return decoder
    }
}

extension JSONEncoder {
    public static var personalAffairs: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(DateFormatters.iso8601.string(from: date))
        }
        return encoder
    }
}

private enum DateFormatters {
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let backendNaiveWithFractional: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return formatter
    }()

    static let backendNaive: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}
