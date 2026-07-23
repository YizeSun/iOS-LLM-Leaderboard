import PowerEvidence
import SwiftUI

struct PowerTestView: View {
    @Bindable var model: PowerAppModel

    var body: some View {
        List {
            Section("Power 2 candidate") {
                LabeledContent(
                    "Benchmark cell",
                    value: "Text performance × physical iPhone"
                )
                LabeledContent(
                    "Stack",
                    value: Power2CandidateIdentity.stackID
                )
                LabeledContent(
                    "Measurement stack",
                    value: abbreviated(
                        Power2CandidateIdentity
                            .measurementStackSHA256
                    )
                )
                LabeledContent(
                    "Runner candidate",
                    value: abbreviated(
                        Power2CandidateIdentity
                            .runnerCandidateManifestSHA256
                    )
                )
                LabeledContent(
                    "Build kind",
                    value: PowerAppBuildIdentity.kind.displayName
                )
                LabeledContent(
                    "Bundle",
                    value: PowerAppBuildIdentity.bundleIdentifier
                )
            }

            Section("Test selection") {
                Picker("Model", selection: $model.selectedModelID) {
                    ForEach(Power2CandidateCatalog.models) { model in
                        Text(model.displayName).tag(model.id)
                    }
                }
                Picker(
                    "Workload",
                    selection: $model.selectedWorkloadID
                ) {
                    ForEach(Power2CandidateCatalog.workloads) { workload in
                        Text(workload.title).tag(workload.id)
                    }
                }
                Picker(
                    "Thermal assistance",
                    selection: $model.thermalAssistance
                ) {
                    ForEach(PowerThermalAssistance.allCases, id: \.self) {
                        assistance in
                        Text(label(for: assistance)).tag(assistance)
                    }
                }
            }
            .disabled(model.runState.isRunning)

            Section {
                if model.measurementAvailable {
                    if PowerAppBuildIdentity.isCertificationBuild {
                        Label(
                            "Certification mode produces candidate "
                                + "evidence only.",
                            systemImage: "wrench.and.screwdriver"
                        )
                        .foregroundStyle(.orange)
                    } else {
                        Label(
                            "Official release identity verified.",
                            systemImage: "checkmark.shield"
                        )
                        .foregroundStyle(.green)
                    }
                } else {
                    Label(
                        lockedReason,
                        systemImage: "lock.shield"
                    )
                    .foregroundStyle(.orange)
                }

                if let status = model.runStatusText {
                    if model.runState.isRunning {
                        ProgressView(status)
                    } else {
                        Text(status)
                            .foregroundStyle(statusColor)
                    }
                }

                if model.runState.isRunning {
                    Button(
                        "Cancel Run",
                        role: .destructive
                    ) {
                        model.cancelRun()
                    }
                } else {
                    Button(runButtonTitle) {
                        model.startRun()
                    }
                    .disabled(!model.measurementAvailable)
                }
            } footer: {
                Text(
                    "Certification evidence uses a candidate certificate ID "
                        + "and cannot pass public intake or enter ranking. "
                        + "Developer builds remain measurement-locked; "
                        + "Official builds unlock only through the generated "
                        + "repository release identity."
                )
            }
        }
        .navigationTitle("Test")
    }

    private func abbreviated(_ digest: String) -> String {
        "\(digest.prefix(12))…\(digest.suffix(8))"
    }

    private var lockedReason: String {
        switch PowerAppBuildIdentity.kind {
        case .developer:
            return "Developer builds can inspect the App but cannot produce "
                + "or submit ranking evidence."
        case .official:
            return "This Official build remains locked until an immutable "
                + "App Release and public Power intake are activated."
        case .invalid:
            return "The compiled build kind does not match the embedded "
                + "PowerBuildKind declaration."
        case .certification:
            return "Certification requires POWER_SOURCE_REVISION to be the "
                + "exact generated App component-manifest SHA-256."
        }
    }

    private var runButtonTitle: String {
        if PowerAppBuildIdentity.isCertificationBuild {
            return "Run Certification Smoke Test"
        }
        return "Run Benchmark"
    }

    private var statusColor: Color {
        if case .failed = model.runState {
            return .red
        }
        return .green
    }

    private func label(
        for assistance: PowerThermalAssistance
    ) -> String {
        switch assistance {
        case .none:
            "None"
        case .deliberateCooling:
            "Deliberate cooling"
        case .deliberateHeating:
            "Deliberate heating"
        case .otherAssisted:
            "Other assistance"
        case .unknown:
            "Unknown"
        }
    }
}
