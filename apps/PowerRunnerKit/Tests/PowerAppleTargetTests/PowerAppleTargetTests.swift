import PowerAppleTarget
import PowerEvidence
import PowerRunnerCore
import XCTest

final class PowerAppleTargetTests: XCTestCase {
    func testOrdinaryAdmissionRequiresEveryTargetCondition() {
        let accepted = AppleIPhoneAdmission.evaluate(
            snapshot: fixtureSnapshot(),
            thermalAssistance: .none
        )
        XCTAssertTrue(accepted.ordinaryRankingEligible)
        XCTAssertTrue(accepted.reasonCodes.isEmpty)

        let rejected = AppleIPhoneAdmission.evaluate(
            snapshot: fixtureSnapshot(
                isPhysicalDevice: false,
                batteryLevel: 0.2,
                batteryState: .charging,
                lowPowerModeEnabled: true,
                thermalState: .fair
            ),
            thermalAssistance: .deliberateCooling
        )
        XCTAssertFalse(rejected.ordinaryRankingEligible)
        XCTAssertEqual(
            rejected.reasonCodes,
            [
                "physical_device_required",
                "battery_state_not_unplugged",
                "battery_level_below_minimum",
                "low_power_mode_enabled",
                "initial_thermal_state_not_nominal",
                "thermal_assistance_not_none",
            ]
        )
    }

    private func fixtureSnapshot(
        isPhysicalDevice: Bool = true,
        batteryLevel: Double = 0.8,
        batteryState: PowerBatteryState = .unplugged,
        lowPowerModeEnabled: Bool = false,
        thermalState: PowerThermalState = .nominal
    ) -> PowerTargetSnapshot {
        PowerTargetSnapshot(
            isPhysicalDevice: isPhysicalDevice,
            device: .init(
                machineIdentifier: "iPhone17,1",
                osVersion: "iOS 26.0",
                osBuild: "23A000"
            ),
            batteryLevel: batteryLevel,
            batteryState: batteryState,
            lowPowerModeEnabled: lowPowerModeEnabled,
            thermalState: thermalState
        )
    }
}
