import Foundation

public enum APIClientError: Error, LocalizedError, Equatable {
    case invalidURL
    case unauthorized
    case server(code: String, message: String)
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "API 地址无效。"
        case .unauthorized:
            return "登录已过期，请重新登录。"
        case .server(_, let message):
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
    public let tokenStore: TokenStore

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(
        baseURL: URL = URL(string: "http://127.0.0.1:8000/api/v1")!,
        tokenStore: TokenStore = KeychainTokenStore(),
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.session = session
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
            throw APIClientError.transport(error.localizedDescription)
        }

        guard let http = urlResponse as? HTTPURLResponse else {
            throw APIClientError.transport("HTTP 响应无效。")
        }

        if http.statusCode == 401, allowRefresh, try await refreshTokensIfPossible() {
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
                if envelope.error.code == "unauthorized" { throw APIClientError.unauthorized }
                throw APIClientError.server(code: envelope.error.code, message: envelope.error.message)
            }
            throw APIClientError.server(code: "http_error", message: "HTTP \(http.statusCode)")
        }

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
        if let token = tokenStore.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }
        return request
    }

    private func refreshTokensIfPossible() async throws -> Bool {
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
            try? tokenStore.clear()
            return false
        }
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
