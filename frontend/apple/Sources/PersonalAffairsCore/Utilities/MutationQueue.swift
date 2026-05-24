import Foundation

public struct PendingMutation: Codable, Identifiable, Equatable {
    public enum Kind: String, Codable, CaseIterable {
        case taskCreate
        case taskUpdate
        case taskStatus
        case taskArchive
        case noteCreate
        case noteUpdate
        case noteArchive
        case calendarCreate
        case calendarUpdate
        case projectCreate
        case projectUpdate
        case projectComplete
        case projectArchive
    }

    public let id: String
    public let kind: Kind
    public let targetId: String?
    public let payload: Data?
    public let createdAt: Date
    /// v1.2.4 (#9 / #26): the cloud user who owned the queue when the mutation
    /// was enqueued. Set by `AppModel` via `localUserId()` at enqueue time;
    /// `replay` skips rows whose `userId` does not match the currently signed-in
    /// user so a logout → login-as-different-user cannot replay user A's
    /// offline writes into user B's account.
    ///
    /// Defaults to `"unknown"` so JSON written by pre-v1.2.4 clients (which do
    /// not carry this field) decodes cleanly. These legacy rows will be
    /// archived to the orphan file on first replay rather than being executed
    /// against an arbitrary user.
    public let userId: String
    /// v1.2.4 (#31): how many times we have attempted to replay this mutation.
    /// Network failures bump this; we only drop permanent once it reaches 5.
    public let attempts: Int

    public init(
        id: String = UUID().uuidString,
        kind: Kind,
        targetId: String? = nil,
        payload: Data? = nil,
        createdAt: Date = Date(),
        userId: String = "unknown",
        attempts: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.targetId = targetId
        self.payload = payload
        self.createdAt = createdAt
        self.userId = userId
        self.attempts = attempts
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.kind = try c.decode(Kind.self, forKey: .kind)
        self.targetId = try c.decodeIfPresent(String.self, forKey: .targetId)
        self.payload = try c.decodeIfPresent(Data.self, forKey: .payload)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        // Legacy rows written by pre-v1.2.4 builds do not have userId / attempts.
        // Fall back gracefully so the queue still loads instead of nuking pending work.
        self.userId = (try c.decodeIfPresent(String.self, forKey: .userId)) ?? "unknown"
        self.attempts = (try c.decodeIfPresent(Int.self, forKey: .attempts)) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case targetId
        case payload
        case createdAt
        case userId
        case attempts
    }

    public static func taskCreate(_ request: TaskCreateRequest) throws -> PendingMutation {
        try PendingMutation(kind: .taskCreate, payload: encode(request))
    }

    public static func taskUpdate(id: String, request: TaskUpdateRequest) throws -> PendingMutation {
        try PendingMutation(kind: .taskUpdate, targetId: id, payload: encode(request))
    }

    public static func taskStatus(id: String, status: TaskStatus) throws -> PendingMutation {
        try PendingMutation(kind: .taskStatus, targetId: id, payload: encode(StatusPayload(taskStatus: status)))
    }

    public static func taskArchive(id: String) -> PendingMutation {
        PendingMutation(kind: .taskArchive, targetId: id)
    }

    public static func noteCreate(_ request: NoteCreateRequest) throws -> PendingMutation {
        try PendingMutation(kind: .noteCreate, payload: encode(request))
    }

    public static func noteUpdate(id: String, request: NoteUpdateRequest) throws -> PendingMutation {
        try PendingMutation(kind: .noteUpdate, targetId: id, payload: encode(request))
    }

    public static func noteArchive(id: String) -> PendingMutation {
        PendingMutation(kind: .noteArchive, targetId: id)
    }

    public static func calendarCreate(_ request: CalendarItemCreateRequest) throws -> PendingMutation {
        try PendingMutation(kind: .calendarCreate, payload: encode(request))
    }

    public static func calendarUpdate(id: String, request: CalendarItemUpdateRequest) throws -> PendingMutation {
        try PendingMutation(kind: .calendarUpdate, targetId: id, payload: encode(request))
    }

    public static func projectCreate(_ request: ProjectCreateRequest) throws -> PendingMutation {
        try PendingMutation(kind: .projectCreate, payload: encode(request))
    }

    public static func projectUpdate(id: String, request: ProjectUpdateRequest) throws -> PendingMutation {
        try PendingMutation(kind: .projectUpdate, targetId: id, payload: encode(request))
    }

    public static func projectComplete(id: String) -> PendingMutation {
        PendingMutation(kind: .projectComplete, targetId: id)
    }

    public static func projectArchive(id: String) -> PendingMutation {
        PendingMutation(kind: .projectArchive, targetId: id)
    }

    /// Returns a copy of this mutation with the given `userId` stamped in.
    /// Called by `MutationQueue.enqueue(_:userId:)` so callers don't have to
    /// thread userId through every factory.
    public func withUserId(_ userId: String) -> PendingMutation {
        PendingMutation(
            id: id,
            kind: kind,
            targetId: targetId,
            payload: payload,
            createdAt: createdAt,
            userId: userId,
            attempts: attempts
        )
    }

    /// Returns a copy with `attempts` incremented by 1. Used by replay to
    /// bump the network-retry counter without losing the rest of the row.
    func bumpingAttempts() -> PendingMutation {
        PendingMutation(
            id: id,
            kind: kind,
            targetId: targetId,
            payload: payload,
            createdAt: createdAt,
            userId: userId,
            attempts: attempts + 1
        )
    }

    private static func encode<Value: Encodable>(_ value: Value) throws -> Data {
        try JSONEncoder.personalAffairs.encode(value)
    }
}

public struct MutationReplayResult: Equatable {
    public let attempted: Int
    public let succeeded: Int
    public let droppedPermanent: Int
    public let remaining: Int
    /// v1.2.4 (#9): rows skipped because they belonged to a different user.
    /// They are archived to the orphan file (not deleted) and never count
    /// against droppedPermanent.
    public let orphanedSkipped: Int

    public init(
        attempted: Int,
        succeeded: Int,
        droppedPermanent: Int,
        remaining: Int,
        orphanedSkipped: Int = 0
    ) {
        self.attempted = attempted
        self.succeeded = succeeded
        self.droppedPermanent = droppedPermanent
        self.remaining = remaining
        self.orphanedSkipped = orphanedSkipped
    }
}

/// v1.2.4 (#31): how many network-failure replay attempts we tolerate before
/// giving up on a mutation. Exposed so tests can assert the exact threshold.
public let mutationQueueMaxNetworkAttempts = 5

/// v1.2.4 (#31): compute the retry delay for the Nth attempt.
/// `attemptNumber` is 1-based: first retry waits 2s, second 4s, ... capped at 30s.
/// Pure function so tests can verify the curve without driving real time.
public func mutationQueueRetryDelaySeconds(attemptNumber: Int) -> TimeInterval {
    let clamped = max(1, attemptNumber)
    let raw = pow(2.0, Double(clamped))
    return min(raw, 30.0)
}

public actor MutationQueue {
    private let fileURL: URL
    private let orphanFileURL: URL
    private let fileManager: FileManager
    private let diagnostics: DiagnosticLogger
    private var pending: [PendingMutation]

    public init(
        fileURL: URL? = nil,
        orphanFileURL: URL? = nil,
        fileManager: FileManager = .default,
        diagnostics: DiagnosticLogger = .shared
    ) {
        self.fileManager = fileManager
        self.diagnostics = diagnostics
        let resolved = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        self.fileURL = resolved
        self.orphanFileURL = orphanFileURL ?? Self.defaultOrphanFileURL(for: resolved)
        self.pending = (try? Self.load(from: resolved, fileManager: fileManager)) ?? []
    }

    /// v1.2.4 (#9 / #26): enqueue a mutation, stamping the current user's id
    /// onto it. Callers that don't know the userId (legacy paths, tests) can
    /// still use the no-arg overload, which preserves whatever userId the
    /// mutation already carries (default `"unknown"`).
    public func enqueue(_ mutation: PendingMutation, userId: String) throws -> Int {
        let stamped = mutation.withUserId(userId)
        pending.append(stamped)
        try persist()
        diagnostics.recordQueue(event: "queue_enqueue", mutationId: stamped.id, kind: stamped.kind.rawValue)
        return pending.count
    }

    /// Backwards-compatible enqueue that does not stamp a userId. Kept for the
    /// (rare) caller that already set userId via `withUserId(_:)`; production
    /// AppModel routes through the overload above.
    public func enqueue(_ mutation: PendingMutation) throws -> Int {
        pending.append(mutation)
        try persist()
        diagnostics.recordQueue(event: "queue_enqueue", mutationId: mutation.id, kind: mutation.kind.rawValue)
        return pending.count
    }

    public func allPending() -> [PendingMutation] {
        pending
    }

    public func pendingCount() -> Int {
        pending.count
    }

    /// v1.2.4 (#9 / #26 / #31): replay all pending mutations for `currentUserId`.
    ///
    /// - Rows whose userId differs from `currentUserId` are archived to the
    ///   orphan file (not deleted, kept for diagnostics) and removed from the
    ///   live queue. They never count against droppedPermanent.
    /// - Network failures (`APIClientError.isNetworkFailure == true`) bump
    ///   `attempts` and pause replay until the next trigger. Only when
    ///   `attempts >= mutationQueueMaxNetworkAttempts` do we drop permanent.
    /// - Between network-retry attempts, callers (the unit tests in
    ///   particular) should consult `mutationQueueRetryDelaySeconds(attemptNumber:)`
    ///   for the backoff schedule; the queue itself only **tracks** attempts,
    ///   the wait happens in the caller's reconnect loop.
    /// - Non-network errors (server validation, 4xx not in network set) keep
    ///   the original behaviour: dropped immediately.
    public func replay(using api: APIClient, currentUserId: String) async -> MutationReplayResult {
        var attempted = 0
        var succeeded = 0
        var dropped = 0
        var orphaned = 0

        while let mutation = pending.first {
            if mutation.userId != currentUserId {
                pending.removeFirst()
                appendOrphan(mutation)
                orphaned += 1
                try? persist()
                diagnostics.recordQueue(
                    event: "queue_replay_orphan_skip",
                    mutationId: mutation.id,
                    kind: mutation.kind.rawValue,
                    error: "user_mismatch \(mutation.userId) != \(currentUserId)"
                )
                continue
            }

            attempted += 1
            do {
                try await replay(mutation, using: api)
                pending.removeFirst()
                succeeded += 1
                try? persist()
                diagnostics.recordQueue(event: "queue_replay_success", mutationId: mutation.id, kind: mutation.kind.rawValue)
            } catch let error as APIClientError where error.isNetworkFailure {
                let bumped = mutation.bumpingAttempts()
                if bumped.attempts >= mutationQueueMaxNetworkAttempts {
                    pending.removeFirst()
                    dropped += 1
                    try? persist()
                    diagnostics.recordQueue(
                        event: "queue_replay_drop_network_exhausted",
                        mutationId: mutation.id,
                        kind: mutation.kind.rawValue,
                        error: error.localizedDescription
                    )
                } else {
                    pending[0] = bumped
                    try? persist()
                    diagnostics.recordQueue(
                        event: "queue_replay_network_retry",
                        mutationId: mutation.id,
                        kind: mutation.kind.rawValue,
                        error: "attempt=\(bumped.attempts) " + error.localizedDescription
                    )
                    break
                }
            } catch {
                pending.removeFirst()
                dropped += 1
                try? persist()
                diagnostics.recordQueue(event: "queue_replay_drop", mutationId: mutation.id, kind: mutation.kind.rawValue, error: UserFacingMessage.translate(error))
            }
        }

        return MutationReplayResult(
            attempted: attempted,
            succeeded: succeeded,
            droppedPermanent: dropped,
            remaining: pending.count,
            orphanedSkipped: orphaned
        )
    }

    /// v1.2.4 (#9): on logout, move every pending row for the **current** user
    /// into the orphan file and clear the live queue. We do not attempt to
    /// transmit them — the user is logging out, so we don't have a valid
    /// session to do so. Keeping them in orphans (instead of deleting) gives
    /// support a paper trail.
    ///
    /// Rows that already belong to other users are also moved (they are not
    /// the current user's, and leaving them around would let them replay into
    /// the next login). The whole live queue is wiped.
    public func archiveAllForCurrentUserAndClear() {
        for mutation in pending {
            appendOrphan(mutation)
            diagnostics.recordQueue(
                event: "queue_logout_archive",
                mutationId: mutation.id,
                kind: mutation.kind.rawValue
            )
        }
        pending.removeAll()
        try? persist()
    }

    public static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("100J", isDirectory: true) ?? fileManager.temporaryDirectory.appendingPathComponent("100J", isDirectory: true)
        return base.appendingPathComponent("mutation-queue.json")
    }

    /// Default orphan archive sits next to the live queue file with a
    /// `MutationQueue.orphanedMutations.json` name (matches the plan).
    public static func defaultOrphanFileURL(for queueURL: URL) -> URL {
        queueURL
            .deletingLastPathComponent()
            .appendingPathComponent("MutationQueue.orphanedMutations.json")
    }

    private static func load(from url: URL, fileManager: FileManager) throws -> [PendingMutation] {
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder.personalAffairs.decode([PendingMutation].self, from: data)
    }

    private func persist() throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder.personalAffairs.encode(pending)
        try data.write(to: fileURL, options: .atomic)
    }

    private func appendOrphan(_ mutation: PendingMutation) {
        do {
            try fileManager.createDirectory(at: orphanFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            var existing: [PendingMutation] = []
            if fileManager.fileExists(atPath: orphanFileURL.path),
               let data = try? Data(contentsOf: orphanFileURL),
               let decoded = try? JSONDecoder.personalAffairs.decode([PendingMutation].self, from: data) {
                existing = decoded
            }
            existing.append(mutation)
            let data = try JSONEncoder.personalAffairs.encode(existing)
            try data.write(to: orphanFileURL, options: .atomic)
        } catch {
            // Best-effort archive; never let a failed orphan write break replay.
            diagnostics.recordQueue(
                event: "queue_orphan_persist_failed",
                mutationId: mutation.id,
                kind: mutation.kind.rawValue,
                error: error.localizedDescription
            )
        }
    }

    private func replay(_ mutation: PendingMutation, using api: APIClient) async throws {
        switch mutation.kind {
        case .taskCreate:
            let request: TaskCreateRequest = try mutation.decodePayload()
            _ = try await api.send("/tasks", method: .post, body: request, response: EmptyResponse.self)
        case .taskUpdate:
            let request: TaskUpdateRequest = try mutation.decodePayload()
            _ = try await api.send("/tasks/\(try mutation.requiredTargetId())", method: .patch, body: request, response: EmptyResponse.self)
        case .taskStatus:
            let payload: StatusPayload = try mutation.decodePayload()
            switch payload.taskStatus {
            case .active:
                _ = try await api.send("/tasks/\(try mutation.requiredTargetId())/reopen", method: .post, response: EmptyResponse.self)
            case .done:
                _ = try await api.send("/tasks/\(try mutation.requiredTargetId())/complete", method: .post, response: EmptyResponse.self)
            case .archived:
                _ = try await api.send("/tasks/\(try mutation.requiredTargetId())/archive", method: .post, response: EmptyResponse.self)
            }
        case .taskArchive:
            _ = try await api.send("/tasks/\(try mutation.requiredTargetId())/archive", method: .post, response: EmptyResponse.self)
        case .noteCreate:
            let request: NoteCreateRequest = try mutation.decodePayload()
            _ = try await api.send("/notes", method: .post, body: request, response: EmptyResponse.self)
        case .noteUpdate:
            let request: NoteUpdateRequest = try mutation.decodePayload()
            _ = try await api.send("/notes/\(try mutation.requiredTargetId())", method: .patch, body: request, response: EmptyResponse.self)
        case .noteArchive:
            _ = try await api.send("/notes/\(try mutation.requiredTargetId())/archive", method: .post, response: EmptyResponse.self)
        case .calendarCreate:
            let request: CalendarItemCreateRequest = try mutation.decodePayload()
            _ = try await api.send("/calendar-items", method: .post, body: request, response: EmptyResponse.self)
        case .calendarUpdate:
            let request: CalendarItemUpdateRequest = try mutation.decodePayload()
            _ = try await api.send("/calendar-items/\(try mutation.requiredTargetId())", method: .patch, body: request, response: EmptyResponse.self)
        case .projectCreate:
            let request: ProjectCreateRequest = try mutation.decodePayload()
            _ = try await api.send("/projects", method: .post, body: request, response: EmptyResponse.self)
        case .projectUpdate:
            let request: ProjectUpdateRequest = try mutation.decodePayload()
            _ = try await api.send("/projects/\(try mutation.requiredTargetId())", method: .patch, body: request, response: EmptyResponse.self)
        case .projectComplete:
            _ = try await api.send("/projects/\(try mutation.requiredTargetId())/complete", method: .post, response: EmptyResponse.self)
        case .projectArchive:
            _ = try await api.send("/projects/\(try mutation.requiredTargetId())/archive", method: .post, response: EmptyResponse.self)
        }
    }
}

private struct StatusPayload: Codable, Equatable {
    let taskStatus: TaskStatus
}

private extension PendingMutation {
    func decodePayload<Value: Decodable>() throws -> Value {
        guard let payload else {
            throw APIClientError.server(code: "invalid_mutation", message: "离线操作缺少 payload。")
        }
        return try JSONDecoder.personalAffairs.decode(Value.self, from: payload)
    }

    func requiredTargetId() throws -> String {
        guard let targetId, !targetId.isEmpty else {
            throw APIClientError.server(code: "invalid_mutation", message: "离线操作缺少目标 ID。")
        }
        return targetId
    }
}
