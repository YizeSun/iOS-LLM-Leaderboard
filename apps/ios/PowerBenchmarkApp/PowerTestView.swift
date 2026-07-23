import SwiftUI

struct PowerTestView: View {
    let model: PowerAppModel

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

            Section {
                Label(
                    "Measurement is locked until this runner is certified "
                        + "and an App release is bound to the active stack.",
                    systemImage: "lock.shield"
                )
                .foregroundStyle(.orange)

                Button("Run Power Test") {}
                    .disabled(!model.measurementAvailable)
            } footer: {
                Text(
                    "This migration build cannot create evidence that looks "
                        + "official. Activation requires a runner certificate, "
                        + "an immutable App release, physical-device "
                        + "verification, and an atomic intake cutover."
                )
            }
        }
        .navigationTitle("Test")
    }

    private func abbreviated(_ digest: String) -> String {
        "\(digest.prefix(12))…\(digest.suffix(8))"
    }
}
