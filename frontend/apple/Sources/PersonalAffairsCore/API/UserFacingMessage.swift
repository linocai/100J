import Foundation

public enum UserFacingMessage {
    public static func translate(_ error: Error) -> String {
        guard let apiError = error as? APIClientError else {
            return error.localizedDescription
        }

        switch apiError {
        case .invalidURL:
            return "API 地址无效，请检查连接设置。"
        case .unauthorized:
            return "登录已过期，请重新登录。"
        case .network:
            return "网络暂时不可用。离线写入会在联网后自动同步。"
        case .transport:
            return "服务暂时不可用，请稍后再试。"
        case .server(let code, let message):
            switch code {
            case "unauthorized":
                return "登录已过期，请重新登录。"
            case "conflict", "version_conflict", "already_exists":
                return "数据已变化，请刷新后再试。"
            case "validation_error", "invalid_request", "missing_spaces", "not_found":
                return "输入内容有问题，请检查后再试。"
            case "rate_limited", "rate_limit_exceeded", "too_many_requests":
                return "操作太频繁，请稍后再试。"
            default:
                return message.isEmpty ? "操作失败，请稍后再试。" : message
            }
        }
    }
}

public extension APIClientError {
    var isNetworkFailure: Bool {
        switch self {
        case .network:
            return true
        case .invalidURL, .server, .transport, .unauthorized:
            return false
        }
    }
}
