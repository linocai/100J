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

    public init(
        id: String = UUID().uuidString,
        kind: Kind,
        targetId: String? = nil,
        payload: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.targetId = targetId
        self.payload = payload
        self.createdAt = createdAt
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

    private static func encode<Value: Encodable>(_ value: Value) throws -> Data {
        try JSONEncoder.personalAffairs.encode(value)
    }
}

public struct MutationReplayResult: Equatable {
    public let attempted: Int
    public let succeeded: Int
    public let droppedPermanent: Int
    public let remaining: Int
}

public actor MutationQueue {
    private let fileURL: URL
    private let fileManager: FileManager
    private let diagnostics: DiagnosticLogger
    private var pending: [PendingMutation]

    public init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        diagnostics: DiagnosticLogger = .shared
    ) {
        self.fileManager = fileManager
        self.diagnostics = diagnostics
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        self.pending = (try? Self.load(from: self.fileURL, fileManager: fileManager)) ?? []
    }

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

    public func replay(using api: APIClient) async -> MutationReplayResult {
        var attempted = 0
        var succeeded = 0
        var dropped = 0

        while let mutation = pending.first {
            attempted += 1
            do {
                try await replay(mutation, using: api)
                pending.removeFirst()
                succeeded += 1
                try? persist()
                diagnostics.recordQueue(event: "queue_replay_success", mutationId: mutation.id, kind: mutation.kind.rawValue)
            } catch let error as APIClientError where error.isNetworkFailure {
                diagnostics.recordQueue(event: "queue_replay_network_retry", mutationId: mutation.id, kind: mutation.kind.rawValue, error: error.localizedDescription)
                break
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
            remaining: pending.count
        )
    }

    public static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("100J", isDirectory: true) ?? fileManager.temporaryDirectory.appendingPathComponent("100J", isDirectory: true)
        return base.appendingPathComponent("mutation-queue.json")
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
