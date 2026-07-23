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
            }

            Section("Certification selection") {
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
            .disabled(model.certificationState.isRunning)

            Section {
                if model.measurementAvailable {
                    Label(
                        "Certification mode produces candidate evidence only.",
                        systemImage: "wrench.and.screwdriver"
                    )
                    .foregroundStyle(.orange)
                } else {
                    Label(
                        lockedReason,
                        systemImage: "lock.shield"
                    )
                    .foregroundStyle(.orange)
                }

                if let status = model.certificationStatusText {
                    if model.certificationState.isRunning {
                        ProgressView(status)
                    } else {
                        Text(status)
                            .foregroundStyle(statusColor)
                    }
                }

                if model.certificationState.isRunning {
                    Button(
                        "Cancel Certification Run",
                        role: .destructive
                    ) {
                        model.cancelCertificationRun()
                    }
                } else {
                    Button("Run Certification Smoke Test") {
                        model.startCertificationRun()
                    }
                    .disabled(!model.measurementAvailable)
                }
            } footer: {
                Text(
                    "Certification evidence uses a candidate certificate ID "
                        + "and cannot pass public intake or enter ranking. "
                        + "Release and Debug builds remain measurement-locked."
                )
            }
        }
        .navigationTitle("Test")
    }

    private func abbreviated(_ digest: String) -> String {
        "\(digest.prefix(12))…\(digest.suffix(8))"
    }

    private var lockedReason: String {
        if !PowerCertificationBuildIdentity.isCertificationBuild {
            return "This build is not the Certification configuration."
        }
        return "Certification requires POWER_SOURCE_REVISION to be the exact "
            + "40- or 64-character Git revision being tested."
    }

    private var statusColor: Color {
        if case .failed = model.certificationState {
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
