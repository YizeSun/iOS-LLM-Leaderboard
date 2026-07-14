import XCTest
@testable import BenchmarkApp

@MainActor
final class PowerAppSettingsTests: XCTestCase {
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

    func testSettingsPersistModelWorkloadAndEnvironmentNotes() {
        let suiteName = "PowerAppSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = PowerAppSettings(defaults: defaults)

        settings.selectedModelProfile = .granite33TwoB
        settings.selectedManualWorkload = .shortInteraction
        settings.ambientTemperatureCelsius = "22.5"
        settings.ambientTemperatureSource = .roomThermometer
        settings.caseState = .removed
        settings.placement = .tabletop
        settings.thermalAssistance = .none

        let restored = PowerAppSettings(defaults: defaults)
        XCTAssertEqual(restored.selectedModelProfile, .granite33TwoB)
        XCTAssertEqual(restored.selectedManualWorkload, .shortInteraction)
        XCTAssertEqual(restored.ambientTemperatureValue, 22.5)
        XCTAssertEqual(restored.ambientTemperatureSource, .roomThermometer)
        XCTAssertEqual(restored.caseState, .removed)
        XCTAssertEqual(restored.placement, .tabletop)
        XCTAssertEqual(restored.thermalAssistance, .none)
    }

    func testEnvironmentObservationBlockIsSeparateFromResultJSON() {
        let suiteName = "PowerObservationBlockTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = PowerAppSettings(defaults: defaults)
        settings.ambientTemperatureCelsius = "21,5"
        settings.ambientTemperatureSource = .thermostat
        settings.caseState = .installed
        settings.placement = .stand
        settings.thermalAssistance = .none

        let block = settings.contributionObservationBlock(
            resultIDs: ["result-a", "result-b"]
        )
        XCTAssertTrue(block.contains("Result IDs: result-a, result-b"))
        XCTAssertTrue(block.contains("Ambient room temperature: 21.5 °C"))
        XCTAssertTrue(block.contains("Case state: installed"))
        XCTAssertTrue(block.contains("Placement: stand"))
        XCTAssertTrue(block.contains("Thermal assistance: none"))
        XCTAssertFalse(block.contains("\"schemaVersion\""))
    }
}
