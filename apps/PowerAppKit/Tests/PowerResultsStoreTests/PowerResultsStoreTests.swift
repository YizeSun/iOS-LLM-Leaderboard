import Foundation
import PowerAppKitTestSupport
import PowerEvidence
import PowerResultsStore
import XCTest

final class PowerResultsStoreTests: XCTestCase {
    func testStoreReturnsTheExactBytesWritten() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PowerResultsStore(directory: directory)
        let bytes = try PowerEvidenceEncoder.encode(
            PowerAppKitFixture.envelope()
        )

        let saved = try await store.save(encodedEvidence: bytes)
        let loaded = try await store.encodedEvidence(for: saved.id)
        let records = try await store.list()

        XCTAssertEqual(loaded, bytes)
        XCTAssertEqual(records, [saved])
        XCTAssertEqual(saved.id, PowerAppKitFixture.resultID)
        XCTAssertEqual(
            saved.workloadID,
            "power.text.short-interaction"
        )
    }

    func testResultIDCannotBeReusedForDifferentBytes() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PowerResultsStore(directory: directory)
        let first = try PowerEvidenceEncoder.encode(
            PowerAppKitFixture.envelope()
        )
        let second = try PowerEvidenceEncoder.encode(
            PowerAppKitFixture.envelope(
                createdAt: "2026-07-23T13:00:00.000Z"
            )
        )

        try await store.save(encodedEvidence: first)
        do {
            try await store.save(encodedEvidence: second)
            XCTFail("collision should fail closed")
        } catch let error as PowerResultsStore.StoreError {
            guard case .resultIDCollision = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
    }
}
