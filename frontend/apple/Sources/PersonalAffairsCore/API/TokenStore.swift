import Foundation
import Security

public protocol TokenStore {
    var accessToken: String? { get }
    var refreshToken: String? { get }
    func save(accessToken: String, refreshToken: String) throws
    func clear() throws
}

public final class InMemoryTokenStore: TokenStore {
    public private(set) var accessToken: String?
    public private(set) var refreshToken: String?

    public init(accessToken: String? = nil, refreshToken: String? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    public func save(accessToken: String, refreshToken: String) throws {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    public func clear() throws {
        accessToken = nil
        refreshToken = nil
    }
}

public final class KeychainTokenStore: TokenStore {
    public static let defaultService = "top.linotsai.app.PersonalAffairs.auth"
    public static let legacyService = "PersonalAffairsApp"
    // Legacy keychain service retained only to migrate existing local sessions.
    public static let legacyMacService = "com.lino.100j.auth"

    private let service: String
    private let legacyServices: [String]
    private let accessAccount = "access_token"
    private let refreshAccount = "refresh_token"

    public init(
        service: String = KeychainTokenStore.defaultService,
        legacyServices: [String] = [KeychainTokenStore.legacyService, KeychainTokenStore.legacyMacService]
    ) {
        self.service = service
        self.legacyServices = legacyServices.filter { $0 != service }
    }

    public var accessToken: String? { token(account: accessAccount) }
    public var refreshToken: String? { token(account: refreshAccount) }

    public func save(accessToken: String, refreshToken: String) throws {
        try save(value: accessToken, account: accessAccount, service: service)
        try save(value: refreshToken, account: refreshAccount, service: service)
        legacyServices.forEach { legacyService in
            delete(account: accessAccount, service: legacyService)
            delete(account: refreshAccount, service: legacyService)
        }
    }

    public func clear() throws {
        delete(account: accessAccount, service: service)
        delete(account: refreshAccount, service: service)
        legacyServices.forEach { legacyService in
            delete(account: accessAccount, service: legacyService)
            delete(account: refreshAccount, service: legacyService)
        }
    }

    private func token(account: String) -> String? {
        if let current = read(account: account, service: service) {
            return current
        }
        migrateLegacyPairIfNeeded()
        if let migrated = read(account: account, service: service) {
            return migrated
        }
        return legacyServices.compactMap { read(account: account, service: $0) }.first
    }

    private func migrateLegacyPairIfNeeded() {
        guard read(account: accessAccount, service: service) == nil || read(account: refreshAccount, service: service) == nil else { return }

        for legacyService in legacyServices {
            guard
                let legacyAccess = read(account: accessAccount, service: legacyService),
                let legacyRefresh = read(account: refreshAccount, service: legacyService)
            else {
                continue
            }

            do {
                try save(value: legacyAccess, account: accessAccount, service: service)
                try save(value: legacyRefresh, account: refreshAccount, service: service)
                delete(account: accessAccount, service: legacyService)
                delete(account: refreshAccount, service: legacyService)
            } catch {
                return
            }
            return
        }
    }

    private func read(account: String, service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func save(value: String, account: String, service: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
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

    private func delete(account: String, service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// v1.2.4 P3-4 (#11): `KeychainAccessGroup` removed. The shared access
// group only takes effect when entitlements declare `keychain-access-groups`,
// and we never shipped that declaration. Keeping the hook around was
// misleading dead code. v1.3.0 can reintroduce it together with the
// entitlement if multi-app keychain sharing actually ships.

public enum KeychainError: Error, LocalizedError {
    case status(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .status(let status):
            return "钥匙串操作失败，状态码 \(status)。"
        }
    }
}
