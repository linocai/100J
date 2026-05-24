import Foundation
import Security

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// 单设备长期会话客户端存储。
///
/// 持久化策略：
/// - `deviceId`：一台机器一份 UUID，写 UserDefaults（不需要保密）
/// - `refreshToken`：写 Keychain（access = whenUnlockedThisDeviceOnly），用 KeychainTokenStore.deviceRefreshAccount
/// - `accessToken`：依旧由 TokenStore 管理（短期，启动后由 silentResume 刷新）
/// - `deviceName` / `expiresAt`：UserDefaults，仅展示
public struct DeviceSessionInfo: Codable, Equatable {
    public let deviceId: String
    public let deviceName: String
    public var expiresAt: Date?
    public var lastRefreshedAt: Date

    public init(deviceId: String, deviceName: String, expiresAt: Date? = nil, lastRefreshedAt: Date = Date()) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.expiresAt = expiresAt
        self.lastRefreshedAt = lastRefreshedAt
    }
}

/// `open` so unit tests can subclass it with an in-memory implementation
/// without touching real Keychain / UserDefaults. Production callsites
/// continue to use the concrete class.
open class DeviceSessionStore {
    public static let shared = DeviceSessionStore()

    private let defaults: UserDefaults
    private let deviceIdKey = "deviceSession.deviceId"
    private let infoKey = "deviceSession.info"
    private let keychainService: String

    public init(
        defaults: UserDefaults = .standard,
        keychainService: String = KeychainTokenStore.defaultService
    ) {
        self.defaults = defaults
        self.keychainService = keychainService
    }

    // MARK: device_id（每台机器一份，永久）

    open var deviceId: String {
        if let existing = defaults.string(forKey: deviceIdKey), !existing.isEmpty {
            return existing
        }
        let new = UUID().uuidString
        defaults.set(new, forKey: deviceIdKey)
        return new
    }

    // MARK: 设备名

    public static var defaultDeviceName: String {
        #if os(macOS)
        return Host.current().localizedName ?? "Mac"
        #elseif os(iOS)
        return UIDevice.current.name
        #else
        return "Device"
        #endif
    }

    public static var defaultPlatform: String {
        #if os(macOS)
        return "macos"
        #elseif os(iOS)
        return "ios"
        #else
        return "other"
        #endif
    }

    // MARK: refresh token（Keychain）

    private let refreshAccount = "device_refresh_token"

    open var refreshToken: String? {
        readKeychain(account: refreshAccount)
    }

    open func saveRefreshToken(_ token: String) throws {
        try writeKeychain(value: token, account: refreshAccount)
    }

    open func clearRefreshToken() {
        deleteKeychain(account: refreshAccount)
    }

    // MARK: 元数据

    open var info: DeviceSessionInfo? {
        get {
            guard let data = defaults.data(forKey: infoKey) else { return nil }
            return try? JSONDecoder().decode(DeviceSessionInfo.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: infoKey)
            } else {
                defaults.removeObject(forKey: infoKey)
            }
        }
    }

    open func recordIssued(deviceName: String?, expiresAt: Date?) {
        info = DeviceSessionInfo(
            deviceId: deviceId,
            deviceName: deviceName ?? Self.defaultDeviceName,
            expiresAt: expiresAt,
            lastRefreshedAt: Date()
        )
    }

    open func clearAll() {
        clearRefreshToken()
        defaults.removeObject(forKey: infoKey)
        // device_id 保留 — 同一台机器再次登录可以复用，方便服务器端识别同设备
    }

    // MARK: 是否有效

    open var hasActiveSession: Bool {
        refreshToken != nil
    }

    // MARK: Keychain primitives（与 KeychainTokenStore 共用同一 service）

    private func readKeychain(account: String) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let group = KeychainAccessGroup.identifier {
            query[kSecAttrAccessGroup as String] = group
        }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func writeKeychain(value: String, account: String) throws {
        let data = Data(value.utf8)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        if let group = KeychainAccessGroup.identifier {
            query[kSecAttrAccessGroup as String] = group
        }
        // 用 AfterFirstUnlockThisDeviceOnly：开机解锁后即可静默读取，
        // 不需要每次 App 启动都触发"允许访问"对话框。
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.status(addStatus) }
        } else if status != errSecSuccess {
            throw KeychainError.status(status)
        }
    }

    private func deleteKeychain(account: String) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        if let group = KeychainAccessGroup.identifier {
            query[kSecAttrAccessGroup as String] = group
        }
        SecItemDelete(query as CFDictionary)
    }
}
