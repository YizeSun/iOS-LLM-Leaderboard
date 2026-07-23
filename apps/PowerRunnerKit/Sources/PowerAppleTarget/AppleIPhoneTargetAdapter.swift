#if os(iOS)
import Darwin
import Foundation
import PowerEvidence
import PowerRunnerCore
import UIKit

public struct AppleIPhoneTargetAdapter: PowerTargetAdapter {
    public init() {}

    public func captureStart() async throws -> PowerTargetSnapshot {
        let deviceValues = await MainActor.run {
            UIDevice.current.isBatteryMonitoringEnabled = true
            return (
                systemName: UIDevice.current.systemName,
                systemVersion: UIDevice.current.systemVersion,
                batteryLevel: UIDevice.current.batteryLevel,
                batteryState: UIDevice.current.batteryState
            )
        }
        let batteryLevel = deviceValues.batteryLevel
        return PowerTargetSnapshot(
            isPhysicalDevice: Self.isPhysicalDevice,
            device: .init(
                machineIdentifier: Self.machineIdentifier,
                osVersion:
                    "\(deviceValues.systemName) \(deviceValues.systemVersion)",
                osBuild: Self.systemBuild
            ),
            batteryLevel: batteryLevel >= 0 ? Double(batteryLevel) : 0,
            batteryState: Self.batteryState(deviceValues.batteryState),
            lowPowerModeEnabled:
                ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalState: Self.thermalState(
                ProcessInfo.processInfo.thermalState
            )
        )
    }

    public func currentThermalState() async -> PowerThermalState {
        Self.thermalState(ProcessInfo.processInfo.thermalState)
    }

    public func currentPhysicalFootprintBytes() async -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size
                / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    $0,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return UInt64(info.phys_footprint)
    }

    private static var isPhysicalDevice: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    private static var machineIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }

    private static var systemBuild: String {
        var size = 0
        guard sysctlbyname("kern.osversion", nil, &size, nil, 0) == 0 else {
            return "unknown"
        }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.osversion", &value, &size, nil, 0) == 0 else {
            return "unknown"
        }
        let bytes = value.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func batteryState(
        _ value: UIDevice.BatteryState
    ) -> PowerBatteryState {
        switch value {
        case .unplugged:
            .unplugged
        case .charging:
            .charging
        case .full:
            .full
        case .unknown:
            .unknown
        @unknown default:
            .unknown
        }
    }

    private static func thermalState(
        _ value: ProcessInfo.ThermalState
    ) -> PowerThermalState {
        switch value {
        case .nominal:
            .nominal
        case .fair:
            .fair
        case .serious:
            .serious
        case .critical:
            .critical
        @unknown default:
            .unknown
        }
    }
}
#endif
