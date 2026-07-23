import PowerResultsStore
import SwiftUI

struct PowerResultsView: View {
    @Bindable var model: PowerAppModel

    var body: some View {
        List {
            if model.isLoadingResults {
                ProgressView("Loading saved Power 2 results…")
            } else if let error = model.resultLoadError {
                ContentUnavailableView(
                    "Results unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if model.results.isEmpty {
                ContentUnavailableView(
                    "No Power 2 results",
                    systemImage: "tray",
                    description: Text(
                        "Completed Power 2 tests will appear here. "
                            + "Power 1.1 files are not imported or converted."
                    )
                )
            } else {
                Section("Saved results") {
                    ForEach(model.results) { result in
                        Button {
                            model.selectedResultID = result.id
                        } label: {
                            ResultRow(
                                result: result,
                                isSelected:
                                    result.id == model.selectedResult?.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let selected = model.selectedResult {
                    Section {
                        LabeledContent(
                            "SHA-256",
                            value: abbreviated(selected.sha256)
                        )
                        LabeledContent(
                            "Bytes",
                            value: selected.byteCount.formatted()
                        )
                        ShareLink(item: selected.fileURL) {
                            Label(
                                "Share raw evidence",
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        Button("Submit to GitHub") {}
                            .disabled(
                                !Power2CandidateIdentity.publicIntakeOpen
                            )
                    } header: {
                        Text("Selected result")
                    } footer: {
                        Text(
                            "The Results Store and submission package preserve "
                                + "the selected file byte-for-byte. GitHub "
                                + "submission remains disabled until Power 2 "
                                + "public intake opens."
                        )
                    }
                }
            }
        }
        .navigationTitle("Results")
        .refreshable {
            await model.reloadResults()
        }
    }

    private func abbreviated(_ digest: String) -> String {
        "\(digest.prefix(12))…\(digest.suffix(8))"
    }
}

private struct ResultRow: View {
    let result: StoredPowerResult
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.workloadID)
                    .font(.headline)
                Text(result.modelArtifactID)
                    .font(.subheadline)
                Text(result.createdAt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Selected")
            }
        }
        .contentShape(Rectangle())
    }
}
