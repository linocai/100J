import Foundation
import XCTest
@testable import PersonalAffairsApp
@testable import PersonalAffairsCore

/// v1.2.4 P1-3 (#8): the 401 self-heal path in `AppModel.run(_:)` and the
/// cleanup contract of `expireCloudSession()`.
///
/// These tests deliberately avoid real networks / Keychain — we inject
/// stub repositories and a stub `DeviceSessionStore` via subclassing.
@MainActor
final class AppModelAuthFlowTests: XCTestCase {
    func test_run_recovers_from_401_via_silent_resume() async {
        let deviceSession = StubDeviceSessionStore(deviceId: "dev-1", refreshToken: "rt")
        let api = APIClient(
            baseURL: URL(string: "http://unit.test/api/v1")!,
            authMode: .cloudJWT,
            tokenStore: InMemoryTokenStore(),
            deviceSession: deviceSession,
            session: URLSession(configuration: .ephemeral)
        )
        let auth = RecordingAuthRepository(api: api, deviceSession: deviceSession)
        auth.silentResumeBehavior = .succeedOnce
        let model = AppModel(authMode: .cloudJWT, api: api, authRepository: auth, deviceSession: deviceSession)

        var attempts = 0
        await model.run {
            attempts += 1
            if attempts == 1 {
                throw APIClientError.unauthorized
            }
            // 2nd attempt — pretend success.
        }

        XCTAssertEqual(attempts, 2, "operation must be retried after silent resume succeeds")
        XCTAssertEqual(auth.silentResumeCalls, 1)
        XCTAssertNil(model.errorMessage, "no red banner on silent resume success")
        XCTAssertEqual(deviceSession.clearAllCalls, 0, "device session must survive silent resume success")
    }

    func test_run_calls_expireCloudSession_when_silent_resume_fails() async {
        let deviceSession = StubDeviceSessionStore(deviceId: "dev-1", refreshToken: "rt")
        let api = APIClient(
            baseURL: URL(string: "http://unit.test/api/v1")!,
            authMode: .cloudJWT,
            tokenStore: InMemoryTokenStore(accessToken: "stale", refreshToken: "stale-r"),
            deviceSession: deviceSession,
            session: URLSession(configuration: .ephemeral)
        )
        let auth = RecordingAuthRepository(api: api, deviceSession: deviceSession)
        auth.silentResumeBehavior = .fail
        let model = AppModel(authMode: .cloudJWT, api: api, authRepository: auth, deviceSession: deviceSession)

        await model.run {
            throw APIClientError.unauthorized
        }

        XCTAssertEqual(auth.silentResumeCalls, 1)
        XCTAssertNotNil(model.errorMessage, "expireCloudSession must surface the red banner")
        XCTAssertEqual(deviceSession.clearAllCalls, 1, "device session must be cleared")
        XCTAssertNil(api.tokenStore.accessToken)
        XCTAssertNil(api.tokenStore.refreshToken)
    }

    func test_expireCloudSession_clears_device_session_store() {
        let deviceSession = StubDeviceSessionStore(deviceId: "dev-1", refreshToken: "rt")
        let api = APIClient(
            baseURL: URL(string: "http://unit.test/api/v1")!,
            authMode: .cloudJWT,
            tokenStore: InMemoryTokenStore(accessToken: "a", refreshToken: "b"),
            deviceSession: deviceSession,
            session: URLSession(configuration: .ephemeral)
        )
        let auth = RecordingAuthRepository(api: api, deviceSession: deviceSession)
        let model = AppModel(authMode: .cloudJWT, api: api, authRepository: auth, deviceSession: deviceSession)
        XCTAssertTrue(deviceSession.hasActiveSession)

        model.expireCloudSession()

        XCTAssertEqual(deviceSession.clearAllCalls, 1)
        XCTAssertFalse(deviceSession.hasActiveSession)
        XCTAssertNil(api.tokenStore.accessToken)
        XCTAssertNil(api.tokenStore.refreshToken)
    }
}

// MARK: - Stubs

private final class RecordingAuthRepository: AuthRepository {
    enum Behavior {
        case succeedOnce
        case fail
    }

    var silentResumeBehavior: Behavior = .succeedOnce
    var silentResumeCalls = 0

    override func silentResume() async throws {
        silentResumeCalls += 1
        switch silentResumeBehavior {
        case .succeedOnce:
            return
        case .fail:
            throw APIClientError.unauthorized
        }
    }
}

private final class StubDeviceSessionStore: DeviceSessionStore {
    private var _deviceId: String
    private var _refreshToken: String?
    private var _info: DeviceSessionInfo?
    var clearAllCalls = 0

    init(deviceId: String, refreshToken: String?) {
        self._deviceId = deviceId
        self._refreshToken = refreshToken
        super.init(
            defaults: UserDefaults(suiteName: "stub-\(UUID().uuidString)")!,
            keychainService: "stub-\(UUID().uuidString)"
        )
    }

    override var deviceId: String { _deviceId }
    override var refreshToken: String? { _refreshToken }
    override func saveRefreshToken(_ token: String) throws { _refreshToken = token }
    override func clearRefreshToken() { _refreshToken = nil }
    override var info: DeviceSessionInfo? {
        get { _info }
        set { _info = newValue }
    }
    override func recordIssued(deviceName: String?, expiresAt: Date?) {
        _info = DeviceSessionInfo(deviceId: _deviceId, deviceName: deviceName ?? "stub", expiresAt: expiresAt)
    }
    override func clearAll() {
        _refreshToken = nil
        _info = nil
        clearAllCalls += 1
    }
    override var hasActiveSession: Bool { _refreshToken != nil }
}
