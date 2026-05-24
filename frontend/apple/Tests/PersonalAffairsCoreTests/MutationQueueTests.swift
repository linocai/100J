import Foundation
import XCTest
@testable import PersonalAffairsCore

/// v1.2.4 P6-3 (#9 / #26 / #31): MutationQueue scoping + retry semantics.
///
/// These tests exercise the four behaviours that landed in v1.2.4:
///
///   1. Replay skips and archives mutations belonging to a different user.
///   2. Network failures are retried up to `mutationQueueMaxNetworkAttempts`
///      times before they count as `droppedPermanent`.
///   3. The exponential-backoff schedule caps at 30 s.
///   4. Logout archives the live queue (no matter whose user it is) and
///      wipes the on-disk pending file.
///
/// To keep things hermetic the tests build a stub `URLProtocol` that returns
/// preprogrammed responses (success / network failure) so we never touch a
/// real server. Each test points the queue at its own temporary file URL so
/// there is zero crosstalk with the developer's real on-disk queue.
final class MutationQueueTests: XCTestCase {

    // MARK: - Helpers

    private func makeTempURLs() -> (queue: URL, orphan: URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("p6-mq-\(UUID().uuidString)", isDirectory: true)
        let queue = dir.appendingPathComponent("mutation-queue.json")
        let orphan = dir.appendingPathComponent("MutationQueue.orphanedMutations.json")
        return (queue, orphan)
    }

    private func makeAPIClient(
        protocolClass: AnyClass
    ) -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [protocolClass]
        let session = URLSession(configuration: config)
        return APIClient(
            baseURL: URL(string: "http://unit.test/api/v1")!,
            authMode: .cloudJWT,
            tokenStore: InMemoryTokenStore(accessToken: "a", refreshToken: "r"),
            deviceSession: nil,
            session: session
        )
    }

    private func makeTaskCreateMutation(userId: String) throws -> PendingMutation {
        let request = TaskCreateRequest(spaceId: "space-1", title: "offline task")
        return try PendingMutation.taskCreate(request).withUserId(userId)
    }

    private func readOrphans(at url: URL) -> [PendingMutation] {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder.personalAffairs.decode([PendingMutation].self, from: data)
        else { return [] }
        return decoded
    }

    // MARK: - test_replay_skips_other_user_mutations_and_archives_them

    func test_replay_skips_other_user_mutations_and_archives_them() async throws {
        let (queueURL, orphanURL) = makeTempURLs()
        let queue = MutationQueue(fileURL: queueURL, orphanFileURL: orphanURL)

        let mineRow = try makeTaskCreateMutation(userId: "user-current")
        let strangerRow = try makeTaskCreateMutation(userId: "user-other")
        _ = try await queue.enqueue(mineRow, userId: "user-current")
        _ = try await queue.enqueue(strangerRow, userId: "user-other")

        AlwaysOKURLProtocol.reset()
        let api = makeAPIClient(protocolClass: AlwaysOKURLProtocol.self)

        let result = await queue.replay(using: api, currentUserId: "user-current")

        XCTAssertEqual(result.succeeded, 1, "the current user's row must replay")
        XCTAssertEqual(result.attempted, 1, "the stranger's row must not be attempted")
        XCTAssertEqual(result.orphanedSkipped, 1, "stranger row counts as orphaned")
        XCTAssertEqual(result.droppedPermanent, 0, "orphan is not a permanent drop")
        XCTAssertEqual(result.remaining, 0)

        let onDisk = await queue.allPending()
        XCTAssertTrue(onDisk.isEmpty, "live queue must be drained")

        let orphans = readOrphans(at: orphanURL)
        XCTAssertEqual(orphans.count, 1, "stranger row must be archived (not deleted)")
        XCTAssertEqual(orphans.first?.userId, "user-other")
        XCTAssertEqual(orphans.first?.id, strangerRow.id)
    }

    // MARK: - test_replay_uses_exponential_backoff_up_to_30s

    func test_replay_uses_exponential_backoff_up_to_30s() {
        // The queue itself does not own a clock — the retry loop is in
        // AppModel — so we just assert the public schedule function. This is
        // the contract that any reconnect/retry caller must follow.
        XCTAssertEqual(mutationQueueRetryDelaySeconds(attemptNumber: 1), 2.0)
        XCTAssertEqual(mutationQueueRetryDelaySeconds(attemptNumber: 2), 4.0)
        XCTAssertEqual(mutationQueueRetryDelaySeconds(attemptNumber: 3), 8.0)
        XCTAssertEqual(mutationQueueRetryDelaySeconds(attemptNumber: 4), 16.0)
        XCTAssertEqual(mutationQueueRetryDelaySeconds(attemptNumber: 5), 30.0, "capped at 30 s")
        XCTAssertEqual(mutationQueueRetryDelaySeconds(attemptNumber: 6), 30.0, "still capped")
        XCTAssertEqual(mutationQueueRetryDelaySeconds(attemptNumber: 100), 30.0, "still capped at huge N")
        XCTAssertEqual(mutationQueueRetryDelaySeconds(attemptNumber: 0), 2.0, "0 clamps to 1st attempt")
        XCTAssertEqual(mutationQueueRetryDelaySeconds(attemptNumber: -3), 2.0, "negative clamps to 1st attempt")
    }

    // MARK: - test_replay_does_not_drop_permanent_on_network_error_within_5_attempts

    func test_replay_does_not_drop_permanent_on_network_error_within_5_attempts() async throws {
        let (queueURL, orphanURL) = makeTempURLs()
        let queue = MutationQueue(fileURL: queueURL, orphanFileURL: orphanURL)

        let mutation = try makeTaskCreateMutation(userId: "user-current")
        _ = try await queue.enqueue(mutation, userId: "user-current")

        FailingNetworkURLProtocol.reset()
        let api = makeAPIClient(protocolClass: FailingNetworkURLProtocol.self)

        // First 4 replay rounds: each round bumps attempts by 1 but never drops.
        for expectedAttempts in 1...4 {
            let result = await queue.replay(using: api, currentUserId: "user-current")
            XCTAssertEqual(result.droppedPermanent, 0, "round \(expectedAttempts) must not drop permanent")
            XCTAssertEqual(result.succeeded, 0, "round \(expectedAttempts) must not succeed")
            XCTAssertEqual(result.remaining, 1, "row stays in queue")
            let pending = await queue.allPending()
            XCTAssertEqual(pending.count, 1)
            XCTAssertEqual(pending.first?.attempts, expectedAttempts)
        }

        // 5th attempt hits the threshold and finally drops permanent.
        let final = await queue.replay(using: api, currentUserId: "user-current")
        XCTAssertEqual(final.droppedPermanent, 1, "5th network failure must drop permanent")
        XCTAssertEqual(final.remaining, 0, "queue is empty after drop")
        let remaining = await queue.allPending()
        XCTAssertTrue(remaining.isEmpty)
    }

    // MARK: - test_logout_archives_queue_for_current_user

    func test_logout_archives_queue_for_current_user() async throws {
        let (queueURL, orphanURL) = makeTempURLs()
        let queue = MutationQueue(fileURL: queueURL, orphanFileURL: orphanURL)

        let mine1 = try makeTaskCreateMutation(userId: "user-current")
        let mine2 = try makeTaskCreateMutation(userId: "user-current")
        let stale = try makeTaskCreateMutation(userId: "user-stale")
        _ = try await queue.enqueue(mine1, userId: "user-current")
        _ = try await queue.enqueue(mine2, userId: "user-current")
        _ = try await queue.enqueue(stale, userId: "user-stale")

        await queue.archiveAllForCurrentUserAndClear()

        let liveAfter = await queue.allPending()
        XCTAssertTrue(liveAfter.isEmpty, "logout must wipe live queue")

        let orphans = readOrphans(at: orphanURL)
        XCTAssertEqual(orphans.count, 3, "all 3 rows must end up in the orphan archive")
        let archivedIDs = Set(orphans.map(\.id))
        XCTAssertEqual(archivedIDs, Set([mine1.id, mine2.id, stale.id]))
    }
}

// MARK: - Test URLProtocols

/// Returns HTTP 200 for every request — used to simulate a server that
/// accepts every offline mutation we replay.
private final class AlwaysOKURLProtocol: URLProtocol {
    static func reset() {}

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Always fails with a network-level error (notConnectedToInternet). The
/// APIClient surfaces this as `APIClientError.network`, which
/// `MutationQueue.replay` treats as a recoverable retry.
private final class FailingNetworkURLProtocol: URLProtocol {
    static func reset() {}

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let err = URLError(.notConnectedToInternet)
        client?.urlProtocol(self, didFailWithError: err)
    }

    override func stopLoading() {}
}
