import Foundation
import Observation
import SwiftUI
import UIKit

enum PowerAppOperationOwner: String, Sendable {
    case manual
    case guided

    var title: String {
        switch self {
        case .manual: "Manual Run"
        case .guided: "Guided Run"
        }
    }
}

enum PowerCaseState: String, CaseIterable, Identifiable, Sendable {
    case installed
    case removed
    case unknown

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum PowerPlacement: String, CaseIterable, Identifiable, Sendable {
    case tabletop
    case stand
    case handheld
    case other
    case unknown

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum PowerAmbientTemperatureSource: String, CaseIterable, Identifiable, Sendable {
    case roomThermometer = "room-thermometer"
    case thermostat
    case weatherService = "weather-service"
    case other
    case notRecorded = "not-recorded"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .roomThermometer: "Room thermometer"
        case .thermostat: "Thermostat"
        case .weatherService: "Weather service"
        case .other: "Other"
        case .notRecorded: "Not recorded"
        }
    }
}

enum PowerThermalAssistance: String, CaseIterable, Identifiable, Sendable {
    case none
    case deliberateCooling = "deliberate-cooling"
    case deliberateHeating = "deliberate-heating"
    case otherAssisted = "other-assisted"
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .deliberateCooling: "Deliberate cooling"
        case .deliberateHeating: "Deliberate heating"
        case .otherAssisted: "Other assistance"
        case .unknown: "Unknown"
        }
    }
}

@MainActor
@Observable
final class PowerAppSettings {
    private enum Key {
        static let modelProfile = "power-app-model-profile"
        static let manualWorkload = "power-app-manual-workload"
        static let ambientTemperature = "power-app-ambient-temperature-celsius"
        static let ambientSource = "power-app-ambient-temperature-source"
        static let caseState = "power-app-case-state"
        static let placement = "power-app-placement"
        static let thermalAssistance = "power-app-thermal-assistance"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var selectedModelProfile: ProductionModelProfile {
        didSet { defaults.set(selectedModelProfile.rawValue, forKey: Key.modelProfile) }
    }

    var selectedManualWorkload: ProductionBenchmarkPlan {
        didSet { defaults.set(selectedManualWorkload.rawValue, forKey: Key.manualWorkload) }
    }

    var ambientTemperatureCelsius: String {
        didSet { defaults.set(ambientTemperatureCelsius, forKey: Key.ambientTemperature) }
    }

    var ambientTemperatureSource: PowerAmbientTemperatureSource {
        didSet { defaults.set(ambientTemperatureSource.rawValue, forKey: Key.ambientSource) }
    }

    var caseState: PowerCaseState {
        didSet { defaults.set(caseState.rawValue, forKey: Key.caseState) }
    }

    var placement: PowerPlacement {
        didSet { defaults.set(placement.rawValue, forKey: Key.placement) }
    }

    var thermalAssistance: PowerThermalAssistance {
        didSet { defaults.set(thermalAssistance.rawValue, forKey: Key.thermalAssistance) }
    }

    private(set) var activeOperation: PowerAppOperationOwner?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedModelProfile = defaults.string(forKey: Key.modelProfile)
            .flatMap { ProductionModelProfile(rawValue: $0) } ?? .small
        selectedManualWorkload = defaults.string(forKey: Key.manualWorkload)
            .flatMap { ProductionBenchmarkPlan(rawValue: $0) }
            ?? .sustainedGeneration
        ambientTemperatureCelsius = defaults.string(
            forKey: Key.ambientTemperature
        ) ?? ""
        ambientTemperatureSource = defaults.string(forKey: Key.ambientSource)
            .flatMap { PowerAmbientTemperatureSource(rawValue: $0) }
            ?? .notRecorded
        caseState = defaults.string(forKey: Key.caseState)
            .flatMap { PowerCaseState(rawValue: $0) } ?? .unknown
        placement = defaults.string(forKey: Key.placement)
            .flatMap { PowerPlacement(rawValue: $0) } ?? .unknown
        thermalAssistance = defaults.string(forKey: Key.thermalAssistance)
            .flatMap { PowerThermalAssistance(rawValue: $0) } ?? .unknown
    }

    var configurationLocked: Bool { activeOperation != nil }

    var ambientTemperatureValue: Double? {
        let normalized = ambientTemperatureCelsius
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty,
              let value = Double(normalized),
              (-50...80).contains(value) else { return nil }
        return value
    }

    var ambientTemperatureEntryIsValid: Bool {
        ambientTemperatureCelsius
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || ambientTemperatureValue != nil
    }

    @discardableResult
    func beginOperation(_ owner: PowerAppOperationOwner) -> Bool {
        guard activeOperation == nil else { return false }
        activeOperation = owner
        return true
    }

    func endOperation(_ owner: PowerAppOperationOwner) {
        guard activeOperation == owner else { return }
        activeOperation = nil
    }

    func clearEnvironmentalObservations() {
        ambientTemperatureCelsius = ""
        ambientTemperatureSource = .notRecorded
        caseState = .unknown
        placement = .unknown
        thermalAssistance = .unknown
    }

    func contributionObservationBlock(resultIDs: [String]) -> String {
        let ids = resultIDs.isEmpty
            ? "add after export"
            : resultIDs.joined(separator: ", ")
        let ambient: String
        if let value = ambientTemperatureValue {
            let stableValue = String(
                format: "%.1f",
                locale: Locale(identifier: "en_US_POSIX"),
                value
            )
            ambient = "\(stableValue) °C (\(ambientTemperatureSource.rawValue))"
        } else {
            ambient = "not recorded"
        }
        return """
        Power 1.0 environmental observations
        - Result IDs: \(ids)
        - Ambient room temperature: \(ambient)
        - Case state: \(caseState.rawValue)
        - Placement: \(placement.rawValue)
        - Thermal assistance: \(thermalAssistance.rawValue)
        """
    }
}

struct PowerEnvironmentObservationsSection: View {
    @Bindable var settings: PowerAppSettings
    let resultIDs: [String]
    @State private var copied = false

    var body: some View {
        Section {
            TextField(
                "Ambient room temperature (°C)",
                text: $settings.ambientTemperatureCelsius
            )
            .keyboardType(.decimalPad)

            Picker("Temperature source", selection: $settings.ambientTemperatureSource) {
                ForEach(PowerAmbientTemperatureSource.allCases) { source in
                    Text(source.title).tag(source)
                }
            }

            Picker("Case", selection: $settings.caseState) {
                ForEach(PowerCaseState.allCases) { state in
                    Text(state.title).tag(state)
                }
            }

            Picker("Placement", selection: $settings.placement) {
                ForEach(PowerPlacement.allCases) { placement in
                    Text(placement.title).tag(placement)
                }
            }

            Picker("Thermal assistance", selection: $settings.thermalAssistance) {
                ForEach(PowerThermalAssistance.allCases) { assistance in
                    Text(assistance.title).tag(assistance)
                }
            }

            if !settings.ambientTemperatureEntryIsValid {
                Label(
                    "Enter a number from −50 to 80, or leave the field empty.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }

            if settings.thermalAssistance != .none {
                Text(settings.thermalAssistance == .unknown
                    ? "Declare None before requesting ordinary live-ranking placement. This does not block measurement."
                    : "Assisted evidence remains reviewable but is not eligible for the ordinary live ranking under the current intake policy.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            Button {
                UIPasteboard.general.string = settings.contributionObservationBlock(
                    resultIDs: resultIDs
                )
                copied = true
            } label: {
                Label(
                    copied ? "Observation Block Copied" : "Copy PR Observation Block",
                    systemImage: copied ? "checkmark" : "doc.on.doc"
                )
            }

            Button("Clear Observations", role: .destructive) {
                settings.clearEnvironmentalObservations()
                copied = false
            }
        } header: {
            Text("Environment observations · optional context")
        } footer: {
            Text("These values are saved locally and copied only when you request it. They never modify the frozen Power result JSON, measurement admission, metrics, or ranking keys.")
        }
        .onChange(of: settings.ambientTemperatureCelsius) { _, _ in copied = false }
        .onChange(of: settings.ambientTemperatureSource) { _, _ in copied = false }
        .onChange(of: settings.caseState) { _, _ in copied = false }
        .onChange(of: settings.placement) { _, _ in copied = false }
        .onChange(of: settings.thermalAssistance) { _, _ in copied = false }
    }
}
