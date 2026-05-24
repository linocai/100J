import Foundation

public final class DiagnosticLogger {
    public static let shared = DiagnosticLogger()

    /// Maximum size of the active diagnostics file before it is rotated to
    /// `<name>.1.log`. Exposed for tests (#29).
    public static let rotationThresholdBytes: Int = 1_000_000

    private let fileManager: FileManager
    private let lock = NSLock()
    private let encoder = JSONEncoder.personalAffairs

    public let directoryURL: URL
    public let fileURL: URL
    public let rotatedFileURL: URL

    public init(
        fileManager: FileManager = .default,
        directoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        let baseDirectory = directoryURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("100J", isDirectory: true) ?? fileManager.temporaryDirectory.appendingPathComponent("100J", isDirectory: true)
        self.directoryURL = baseDirectory
        self.fileURL = baseDirectory.appendingPathComponent("diagnostics.jsonl")
        self.rotatedFileURL = baseDirectory.appendingPathComponent("diagnostics.1.log")
    }

    public func recordAPI(method: String, path: String, status: Int?, error: String?) {
        record(
            event: "api",
            fields: [
                "method": method,
                "path": path,
                "status": status.map(String.init) ?? "",
                "error": error ?? ""
            ]
        )
    }

    public func recordQueue(event: String, mutationId: String? = nil, kind: String? = nil, error: String? = nil) {
        record(
            event: event,
            fields: [
                "mutation_id": mutationId ?? "",
                "kind": kind ?? "",
                "error": error ?? ""
            ]
        )
    }

    public func recordSession(event: String, error: String? = nil) {
        record(event: event, fields: ["error": error ?? ""])
    }

    public func exportLast24Hours(now: Date = Date(), destinationDirectory: URL? = nil) throws -> URL {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let cutoff = now.addingTimeInterval(-24 * 60 * 60)
        let lines = (try? String(contentsOf: fileURL, encoding: .utf8))?
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init) ?? []
        let filtered = lines.filter { line in
            guard let data = line.data(using: .utf8),
                  let entry = try? JSONDecoder.personalAffairs.decode(DiagnosticEntry.self, from: data)
            else {
                return false
            }
            return entry.timestamp >= cutoff
        }
        let diagnosticsData = Data((filtered.joined(separator: "\n") + (filtered.isEmpty ? "" : "\n")).utf8)
        let metadata = DiagnosticMetadata(
            generatedAt: now,
            windowHours: 24,
            appGroupID: WidgetSnapshotStore.appGroupID
        )
        let metadataData = try encoder.encode(metadata)
        let outputDirectory = destinationDirectory ?? fileManager.temporaryDirectory
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let outputURL = outputDirectory.appendingPathComponent("100J-diagnostics-\(Int(now.timeIntervalSince1970)).zip")
        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }
        let archive = ZipArchive(entries: [
            ZipArchive.Entry(name: "diagnostics.jsonl", data: diagnosticsData),
            ZipArchive.Entry(name: "metadata.json", data: metadataData)
        ])
        try archive.write(to: outputURL)
        return outputURL
    }

    private func record(event: String, fields: [String: String]) {
        let entry = DiagnosticEntry(timestamp: Date(), event: event, fields: fields)
        guard let data = try? encoder.encode(entry),
              let line = String(data: data, encoding: .utf8)?.appending("\n").data(using: .utf8)
        else {
            return
        }

        lock.lock()
        defer { lock.unlock() }
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: line)
                try handle.close()
            } else {
                try line.write(to: fileURL)
            }
            rotateIfNeededLocked()
        } catch {
            // Diagnostics must never block the user's primary workflow.
        }
    }

    /// Caller MUST hold `lock`. Moves the active log to `diagnostics.1.log` when
    /// its size exceeds `rotationThresholdBytes`, then re-creates an empty
    /// active log. Best-effort: any IO failure is swallowed so diagnostics
    /// never block user flows.
    private func rotateIfNeededLocked() {
        let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
        let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        guard size > DiagnosticLogger.rotationThresholdBytes else { return }
        do {
            if fileManager.fileExists(atPath: rotatedFileURL.path) {
                try fileManager.removeItem(at: rotatedFileURL)
            }
            try fileManager.moveItem(at: fileURL, to: rotatedFileURL)
            try Data().write(to: fileURL)
        } catch {
            // Rotation failures must not surface to the user; the next write
            // will just retry. Worst case the active log grows past threshold.
        }
    }
}

private struct DiagnosticEntry: Codable {
    let timestamp: Date
    let event: String
    let fields: [String: String]
}

private struct DiagnosticMetadata: Codable {
    let generatedAt: Date
    let windowHours: Int
    let appGroupID: String
}

private struct ZipArchive {
    struct Entry {
        let name: String
        let data: Data
    }

    struct CentralRecord {
        let name: Data
        let crc: UInt32
        let size: UInt32
        let offset: UInt32
    }

    let entries: [Entry]

    func write(to url: URL) throws {
        var archive = Data()
        var centralRecords: [CentralRecord] = []

        for entry in entries {
            let nameData = Data(entry.name.utf8)
            let crc = CRC32.checksum(entry.data)
            let size = UInt32(entry.data.count)
            let offset = UInt32(archive.count)
            archive.appendUInt32(0x04034b50)
            archive.appendUInt16(20)
            archive.appendUInt16(0)
            archive.appendUInt16(0)
            archive.appendUInt16(0)
            archive.appendUInt16(0)
            archive.appendUInt32(crc)
            archive.appendUInt32(size)
            archive.appendUInt32(size)
            archive.appendUInt16(UInt16(nameData.count))
            archive.appendUInt16(0)
            archive.append(nameData)
            archive.append(entry.data)
            centralRecords.append(CentralRecord(name: nameData, crc: crc, size: size, offset: offset))
        }

        let centralOffset = UInt32(archive.count)
        for record in centralRecords {
            archive.appendUInt32(0x02014b50)
            archive.appendUInt16(20)
            archive.appendUInt16(20)
            archive.appendUInt16(0)
            archive.appendUInt16(0)
            archive.appendUInt16(0)
            archive.appendUInt16(0)
            archive.appendUInt32(record.crc)
            archive.appendUInt32(record.size)
            archive.appendUInt32(record.size)
            archive.appendUInt16(UInt16(record.name.count))
            archive.appendUInt16(0)
            archive.appendUInt16(0)
            archive.appendUInt16(0)
            archive.appendUInt16(0)
            archive.appendUInt32(0)
            archive.appendUInt32(record.offset)
            archive.append(record.name)
        }
        let centralSize = UInt32(archive.count) - centralOffset
        archive.appendUInt32(0x06054b50)
        archive.appendUInt16(0)
        archive.appendUInt16(0)
        archive.appendUInt16(UInt16(centralRecords.count))
        archive.appendUInt16(UInt16(centralRecords.count))
        archive.appendUInt32(centralSize)
        archive.appendUInt32(centralOffset)
        archive.appendUInt16(0)
        try archive.write(to: url)
    }
}

private enum CRC32 {
    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffff_ffff
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xff)
            crc = (crc >> 8) ^ table[index]
        }
        return crc ^ 0xffff_ffff
    }

    private static let table: [UInt32] = (0..<256).map { value in
        var crc = UInt32(value)
        for _ in 0..<8 {
            if crc & 1 == 1 {
                crc = (crc >> 1) ^ 0xedb8_8320
            } else {
                crc >>= 1
            }
        }
        return crc
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        append(contentsOf: [UInt8(value & 0xff), UInt8((value >> 8) & 0xff)])
    }

    mutating func appendUInt32(_ value: UInt32) {
        append(contentsOf: [
            UInt8(value & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 24) & 0xff)
        ])
    }
}
