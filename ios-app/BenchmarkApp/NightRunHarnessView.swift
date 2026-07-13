import SwiftUI
import UIKit

struct NightRunHarnessView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = NightRunHarnessViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(
                        "Special branch utility — never merge into main",
                        systemImage: "moon.stars.fill"
                    )
                    .foregroundStyle(.orange)
                    Text("It only orchestrates the existing Power 1.0 runner. Workloads, result schema, metrics, validation, and ranking logic are unchanged.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Night Run Harness")
                }

                Section("Models") {
                    ForEach(ProductionModelProfile.allCases) { profile in
                        Toggle(
                            profile.title,
                            isOn: Binding(
                                get: { viewModel.isSelected(profile) },
                                set: {
                                    viewModel.setSelected(profile, selected: $0)
                                }
                            )
                        )
                        .disabled(viewModel.isBusy)
                    }
                }

                Section {
                    Button("Prepare Selected Models") {
                        Task { await viewModel.prepareSelectedModels() }
                    }
                    .disabled(viewModel.isBusy || viewModel.selectedProfiles.isEmpty)

                    NightPreparationRows(rows: viewModel.preparationRows)
                } header: {
                    Text("1 · Wired cache preparation")
                } footer: {
                    Text("Downloads are allowed here. If any download occurs, fully close and relaunch the App before measurement.")
                }

                Section {
                    LabeledContent("Battery", value: batteryDescription)
                    LabeledContent("Thermal", value: viewModel.runner.currentThermalState)
                    LabeledContent("Build", value: viewModel.runner.buildConfiguration)
                    LabeledContent(
                        "Debugger",
                        value: viewModel.runner.debuggerAttached ? "Attached" : "Detached"
                    )
                    LabeledContent(
                        "Low Power Mode",
                        value: viewModel.runner.lowPowerModeEnabled ? "On" : "Off"
                    )
                } header: {
                    Text("2 · Unplugged preflight")
                } footer: {
                    Text("Disconnect USB and all charging before starting. The queue stops rather than weakening Power 1.0 admission rules.")
                }

                Section {
                    HStack {
                        Button("Start Night Run") {
                            viewModel.start()
                        }
                        .disabled(viewModel.isBusy || viewModel.restartRequired)

                        if viewModel.isBusy {
                            Button("Stop", role: .destructive) {
                                viewModel.stop()
                            }
                        }
                    }
                    Text(viewModel.statusText)
                        .font(.footnote)
                        .foregroundStyle(statusColor)
                } header: {
                    Text("3 · Existing Power workloads")
                } footer: {
                    Text("The screen stays awake while the queue is active. Leaving the App foreground stops the queue for review.")
                }

                if !viewModel.cells.isEmpty {
                    Section("Queue · \(viewModel.completedCount)/\(viewModel.cells.count)") {
                        NightQueueRows(cells: viewModel.cells)
                        Button("Clear Queue", role: .destructive) {
                            Task { await viewModel.resetQueue() }
                        }
                        .disabled(viewModel.isBusy)
                    }
                }
            }
            .navigationTitle("Night Run")
            .task {
                viewModel.runner.refreshThermalState()
                await viewModel.restore()
            }
            .onChange(of: viewModel.isBusy) { _, busy in
                UIApplication.shared.isIdleTimerDisabled = busy
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    viewModel.appDidLeaveForeground()
                }
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    private var batteryDescription: String {
        guard let level = viewModel.runner.batteryLevelPercent else {
            return viewModel.runner.batteryState
        }
        return "\(level.formatted(.number.precision(.fractionLength(0))))% · \(viewModel.runner.batteryState)"
    }

    private var statusColor: Color {
        switch viewModel.phase {
        case .failed, .restartRequired, .stopped: .orange
        default: .secondary
        }
    }

}

private struct NightPreparationRows: View {
    let rows: [NightRunHarnessViewModel.PreparationRow]

    var body: some View {
        ForEach(rows, id: \.id) { row in
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                Text(description(row))
                    .font(.caption)
                    .foregroundStyle(row.loaded ? Color.secondary : Color.red)
            }
        }
    }

    private func description(
        _ row: NightRunHarnessViewModel.PreparationRow
    ) -> String {
        let action = row.downloaded ? "downloaded" : row.cacheState.rawValue
        let load = row.loaded ? "loaded" : "load failed"
        let reasons = row.reasonCodes.isEmpty
            ? ""
            : " · \(row.reasonCodes.joined(separator: ", "))"
        return "\(action) · \(load)\(reasons)"
    }
}

private struct NightQueueRows: View {
    let cells: [NightRunCell]

    var body: some View {
        ForEach(cells, id: \.id) { cell in
            VStack(alignment: .leading, spacing: 3) {
                Text(title(cell))
                Text(cell.status.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(
                        cell.status == .failed ? Color.red : Color.secondary
                    )
                if let message = cell.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let filename = cell.resultFilename {
                    Text(filename)
                        .font(.caption2.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func title(_ cell: NightRunCell) -> String {
        let model = ProductionModelProfile(rawValue: cell.modelProfileID)?
            .planModelProfile.displayName ?? cell.modelProfileID
        return "\(model) · \(cell.workloadID)"
    }
}
