import XCTest
@testable import BenchmarkApp

final class NightRunHarnessTests: XCTestCase {
    func testNightPlanContainsOneModelAndTwoFrozenWorkloads() {
        let cells = NightRunPlan.cells(for: .gemma3OneB)

        XCTAssertEqual(cells.count, 2)
        XCTAssertEqual(
            Set(cells.map(\.modelProfileID)),
            Set([ProductionModelProfile.gemma3OneB.rawValue])
        )
        XCTAssertEqual(
            Set(cells.map(\.workloadID)),
            [
                "b-ux-001-short-interaction",
                "b-pipe-001-sustained-generation",
            ]
        )
        XCTAssertTrue(cells.allSatisfy { $0.status == .pending })
    }

    func testNightPlanUsesOnlyExistingProductionIdentities() {
        for profile in ProductionModelProfile.allCases {
            for cell in NightRunPlan.cells(for: profile) {
                XCTAssertEqual(cell.modelProfileID, profile.rawValue)
                XCTAssertTrue(ProductionBenchmarkPlan.allCases.contains {
                    $0.workloadID == cell.workloadID
                })
            }
        }
    }

    func testQueueStoreRoundTripsWithoutPowerResultData() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let store = NightRunQueueStore(
            fileURL: directory.appending(path: "queue.json")
        )
        let snapshot = NightRunQueueSnapshot(
            selectedModelProfileIDs: [ProductionModelProfile.gemma3OneB.rawValue],
            cells: NightRunPlan.cells(for: .gemma3OneB),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )

        try await store.save(snapshot)
        let loaded = try await store.load()
        XCTAssertEqual(loaded, snapshot)
        try await store.clear()
        let cleared = try await store.load()
        XCTAssertNil(cleared)
    }

    func testProcessIsolationGateAllowsOnlyOneModelIdentity() async throws {
        let gate = ModelProcessIsolationGate()

        try await gate.claim("model-a@revision")
        try await gate.claim("model-a@revision")

        do {
            try await gate.claim("model-b@revision")
            XCTFail("Expected a process-isolation failure")
        } catch let error as ModelProcessIsolationGate.GateError {
            XCTAssertEqual(
                error,
                .differentModelAlreadyClaimed(
                    claimedIdentity: "model-a@revision",
                    requestedIdentity: "model-b@revision"
                )
            )
        }
    }

    func testDownloadGateClearsOnlyAfterANewProcessIdentity() {
        let suiteName = "NightRunHarnessTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let firstLaunch = NightRunLaunchGate(
            defaults: defaults,
            launchID: "launch-a"
        )
        let secondLaunch = NightRunLaunchGate(
            defaults: defaults,
            launchID: "launch-b"
        )

        XCTAssertFalse(firstLaunch.restartRequired)
        firstLaunch.recordDownload()
        XCTAssertTrue(firstLaunch.restartRequired)
        XCTAssertFalse(secondLaunch.restartRequired)
    }
}
