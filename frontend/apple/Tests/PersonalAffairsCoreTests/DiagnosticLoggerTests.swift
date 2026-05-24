import XCTest
@testable import PersonalAffairsCore

final class DiagnosticLoggerTests: XCTestCase {
    private var tempDirectory: URL!
    private var logger: DiagnosticLogger!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiagnosticLoggerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        logger = DiagnosticLogger(directoryURL: tempDirectory)
    }

    override func tearDownWithError() throws {
        logger = nil
        if let directory = tempDirectory {
            try? FileManager.default.removeItem(at: directory)
        }
        tempDirectory = nil
        try super.tearDownWithError()
    }

    func testRotationCreatesArchiveAndResetsActiveFile() throws {
        // Build an event whose serialized length pushes us toward the threshold
        // quickly. Roughly 4 KB per record × ~300 writes ≈ 1.2 MB.
        let bigValue = String(repeating: "x", count: 4_000)
        for _ in 0..<300 {
            logger.recordSession(event: "bulk", error: bigValue)
        }

        let attributesAfter = try FileManager.default.attributesOfItem(atPath: logger.fileURL.path)
        let activeSize = (attributesAfter[.size] as? NSNumber)?.intValue ?? -1

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: logger.rotatedFileURL.path),
            "rotated archive should exist after threshold breach"
        )
        XCTAssertLessThanOrEqual(
            activeSize,
            DiagnosticLogger.rotationThresholdBytes,
            "active log should have been truncated after rotation"
        )

        let rotatedAttributes = try FileManager.default.attributesOfItem(
            atPath: logger.rotatedFileURL.path
        )
        let rotatedSize = (rotatedAttributes[.size] as? NSNumber)?.intValue ?? 0
        XCTAssertGreaterThan(
            rotatedSize,
            DiagnosticLogger.rotationThresholdBytes,
            "rotated archive should hold the data that overflowed the active log"
        )
    }

    func testRotationOverwritesPreviousArchive() throws {
        // Seed an old archive file that should be replaced by the next rotation.
        try Data("old archive\n".utf8).write(to: logger.rotatedFileURL)
        let originalSize = (try FileManager.default.attributesOfItem(
            atPath: logger.rotatedFileURL.path
        )[.size] as? NSNumber)?.intValue ?? 0

        let bigValue = String(repeating: "y", count: 4_000)
        for _ in 0..<300 {
            logger.recordSession(event: "bulk", error: bigValue)
        }

        let newSize = (try FileManager.default.attributesOfItem(
            atPath: logger.rotatedFileURL.path
        )[.size] as? NSNumber)?.intValue ?? 0
        XCTAssertNotEqual(originalSize, newSize, "old archive should have been replaced")
        XCTAssertGreaterThan(newSize, originalSize)
    }
}
