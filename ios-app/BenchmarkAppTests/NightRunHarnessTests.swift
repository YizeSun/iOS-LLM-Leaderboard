import XCTest
@testable import BenchmarkApp

final class NightRunHarnessTests: XCTestCase {
    func testDefaultNightPlanContainsFourModelsAndTwoFrozenWorkloads() {
        let cells = NightRunPlan.cells(for: NightRunPlan.defaultProfiles)

        XCTAssertEqual(cells.count, 8)
        XCTAssertEqual(Set(cells.map(\.modelProfileID)).count, 4)
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
        let cells = NightRunPlan.cells(for: ProductionModelProfile.allCases)

        for cell in cells {
            XCTAssertNotNil(ProductionModelProfile(rawValue: cell.modelProfileID))
            XCTAssertTrue(ProductionBenchmarkPlan.allCases.contains {
                $0.workloadID == cell.workloadID
            })
        }
    }

    func testQueueStoreRoundTripsWithoutPowerResultData() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let store = NightRunQueueStore(
            fileURL: directory.appending(path: "queue.json")
        )
        let snapshot = NightRunQueueSnapshot(
            selectedModelProfileIDs: NightRunPlan.defaultProfiles.map(\.rawValue),
            cells: NightRunPlan.cells(for: NightRunPlan.defaultProfiles),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )

        try await store.save(snapshot)
        let loaded = try await store.load()
        XCTAssertEqual(loaded, snapshot)
        try await store.clear()
        let cleared = try await store.load()
        XCTAssertNil(cleared)
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
