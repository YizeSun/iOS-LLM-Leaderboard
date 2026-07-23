import PowerEvidence
import PowerRunnerCore

public struct AppleIPhoneAdmissionDecision: Sendable, Equatable {
    public let ordinaryRankingEligible: Bool
    public let reasonCodes: [String]

    public init(
        ordinaryRankingEligible: Bool,
        reasonCodes: [String]
    ) {
        self.ordinaryRankingEligible = ordinaryRankingEligible
        self.reasonCodes = reasonCodes
    }
}
public enum AppleIPhoneAdmission {
    public static func evaluate(
        snapshot: PowerTargetSnapshot,
        thermalAssistance: PowerThermalAssistance
    ) -> AppleIPhoneAdmissionDecision {
        var reasons: [String] = []
        if !snapshot.isPhysicalDevice {
            reasons.append("physical_device_required")
        }
        if snapshot.batteryState != .unplugged {
            reasons.append("battery_state_not_unplugged")
        }
        if snapshot.batteryLevel < 0.30 {
            reasons.append("battery_level_below_minimum")
        }
        if snapshot.lowPowerModeEnabled {
            reasons.append("low_power_mode_enabled")
        }
        if snapshot.thermalState != .nominal {
            reasons.append("initial_thermal_state_not_nominal")
        }
        if thermalAssistance != .none {
            reasons.append("thermal_assistance_not_none")
        }
        return AppleIPhoneAdmissionDecision(
            ordinaryRankingEligible: reasons.isEmpty,
            reasonCodes: reasons
        )
    }
}
