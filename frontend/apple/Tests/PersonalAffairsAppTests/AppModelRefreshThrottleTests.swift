import Foundation
import XCTest
@testable import PersonalAffairsApp
@testable import PersonalAffairsCore

/// v1.2.4 P6-4 (#27): `refreshAll()` must coalesce repeat calls within a
/// `refreshAllThrottleSeconds` window, but `refreshAll(force: true)` must
/// always bypass the throttle.
///
/// We do not exercise the full network path here — the bootstrap and load
/// helpers fan out into ~6 repositories, and stubbing them all just to
/// verify a 30-second timer would be more code than the feature. Instead
/// we observe the **public contract**: throttled calls leave
/// `lastRefreshAllAt` untouched (proving the body short-circuited before
/// the network round-trip), and force calls update it.
@MainActor
final class AppModelRefreshThrottleTests: XCTestCase {

    func test_refreshAll_within_30s_is_skipped_unless_forced() async {
        let model = makeModel()

        // Prime the throttle window so the next call is inside the cooldown.
        let primed = Date()
        model.lastRefreshAllAt = primed

        // Throttled call must NOT execute the body (i.e. must not touch
        // network) and must leave the timestamp untouched.
        await model.refreshAll(force: false)
        XCTAssertEqual(
            model.lastRefreshAllAt,
            primed,
            "throttled refreshAll() must short-circuit and leave lastRefreshAllAt unchanged"
        )
        XCTAssertNil(model.errorMessage, "throttled refresh must not surface an error banner")

        // Force call must bypass the throttle. We expect it to actually
        // try to talk to the server; that lights up the network code path,
        // which in this hermetic test will fail because the auth repo
        // throws .unauthorized. The important assertion is that the throttle
        // was bypassed — observable as either a new timestamp (success
        // path) OR an error surfacing (network/auth path). Asserting the
        // body executed is enough; we don't care about the outcome here.
        let snapshotErr = model.errorMessage
        let snapshotTs = model.lastRefreshAllAt
        await model.refreshAll(force: true)
        let bodyExecuted = (model.lastRefreshAllAt != snapshotTs) || (model.errorMessage != snapshotErr)
        XCTAssertTrue(
            bodyExecuted,
            "force: true must bypass the throttle and run the refresh body"
        )
    }

    // MARK: - Helpers

    private func makeModel() -> AppModel {
        let deviceSession = ThrottleStubDeviceSessionStore()
        let api = APIClient(
            baseURL: URL(string: "http://unit.test/api/v1")!,
            authMode: .cloudJWT,
            tokenStore: InMemoryTokenStore(accessToken: "a", refreshToken: "r"),
            deviceSession: deviceSession,
            session: URLSession(configuration: .ephemeral)
        )
        let auth = ThrottleStubAuthRepository(api: api, deviceSession: deviceSession)
        return AppModel(
            authMode: .cloudJWT,
            api: api,
            authRepository: auth,
            deviceSession: deviceSession,
            startsNetworkMonitor: false
        )
    }
}

/// Force every auth call to fail unauthorized so the force-refresh path
/// throws immediately (and surfaces `errorMessage`) without needing a real
/// server. We never reach this stub on the throttled path — that is the
/// whole point of the throttle.
private final class ThrottleStubAuthRepository: AuthRepository {
    override func me() async throws -> User {
        throw APIClientError.unauthorized
    }
    override func silentResume() async throws {
        throw APIClientError.unauthorized
    }
}

private final class ThrottleStubDeviceSessionStore: DeviceSessionStore {
    init() {
        super.init(
            defaults: UserDefaults(suiteName: "throttle-stub-\(UUID().uuidString)")!,
            keychainService: "throttle-stub-\(UUID().uuidString)"
        )
    }
    override var deviceId: String { "throttle-stub-device" }
    override var refreshToken: String? { nil }
    override var hasActiveSession: Bool { false }
    override func clearAll() {}
}
