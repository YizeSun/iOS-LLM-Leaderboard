import Foundation
import Observation
import PowerAppleTarget
import PowerEvidence
import PowerMLXRuntime
import PowerResultsStore
import PowerRunnerCore
import PowerTextProgram

@MainActor
@Observable
final class PowerAppModel {
    enum SelectedTab: Hashable {
        case test
        case results
    }

    enum RunState: Equatable {
        case idle
        case preparingModel
        case running
        case saving
        case completed(UUID)
        case failed(String)

        var isRunning: Bool {
            switch self {
            case .preparingModel, .running, .saving:
                true
            case .idle, .completed, .failed:
                false
            }
        }
    }

    var selectedTab: SelectedTab = .test
    var results: [StoredPowerResult] = []
    var selectedResultID: UUID?
    var resultLoadError: String?
    var isLoadingResults = false
    var selectedModelID =
        Power2CandidateCatalog.models.first?.id ?? ""
    var selectedWorkloadID =
        Power2CandidateCatalog.workloads.first?.id ?? ""
    var thermalAssistance: PowerThermalAssistance = .none
    var runState: RunState = .idle

    @ObservationIgnored
    private var runTask: Task<Void, Never>?

    let store: PowerResultsStore

    init() {
        let fileManager = FileManager.default
        let documents = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        store = PowerResultsStore(
            directory: documents.appendingPathComponent(
                "Power2Results",
                isDirectory: true
            )
        )
    }

    var selectedResult: StoredPowerResult? {
        guard let selectedResultID else {
            return results.first
        }
        return results.first { $0.id == selectedResultID }
    }

    var measurementAvailable: Bool {
        PowerAppBuildIdentity.measurementAvailable
    }

    var submissionAvailable: Bool {
        PowerAppBuildIdentity.officialReleaseAvailable
            && Power2CandidateIdentity.appReleaseAvailable
            && Power2CandidateIdentity.publicIntakeOpen
    }

    var selectedModel: Power2CandidateModelDefinition? {
        Power2CandidateCatalog.models.first {
            $0.id == selectedModelID
        }
    }

    var selectedWorkload: Power2CandidateWorkloadDefinition? {
        Power2CandidateCatalog.workloads.first {
            $0.id == selectedWorkloadID
        }
    }

    var runStatusText: String? {
        switch runState {
        case .idle:
            nil
        case .preparingModel:
            "Preparing the exact pinned model revision…"
        case .running:
            "Running one warmup and five measured attempts…"
        case .saving:
            "Encoding and saving immutable evidence…"
        case .completed:
            "Evidence saved locally."
        case .failed(let message):
            message
        }
    }

    func startRun() {
        guard measurementAvailable, !runState.isRunning else {
            return
        }
        runTask = Task {
            await performRun()
        }
    }

    func cancelRun() {
        runTask?.cancel()
    }

    func reloadResults() async {
        isLoadingResults = true
        defer { isLoadingResults = false }
        do {
            results = try await store.list()
            resultLoadError = nil
            if let selectedResultID,
               results.contains(where: { $0.id == selectedResultID }) {
                return
            }
            selectedResultID = results.first?.id
        } catch {
            results = []
            selectedResultID = nil
            resultLoadError = String(describing: error)
        }
    }

    private func performRun() async {
        defer { runTask = nil }
        do {
            guard
                let model = selectedModel,
                let workloadDefinition = selectedWorkload,
                let appRelease = PowerAppBuildIdentity.appRelease
            else {
                throw RunError.incompleteBuildIdentity
            }

            let target = AppleIPhoneTargetAdapter()
            let preflight = try await target.captureStart()
            guard preflight.isPhysicalDevice else {
                throw RunError.physicalDeviceRequired
            }

            runState = .preparingModel
            let descriptor = try model.descriptor()
            let runtime = try await PowerMLXModelLoader.load(
                descriptor: descriptor,
                localFilesOnly: false
            )
            try Task.checkCancellation()

            let workload = try workloadDefinition.workload()
            let fixture = try workloadDefinition.fixture()
            let requests = try PowerTextProgramModule.makeRequests(
                workload: workload,
                fixture: fixture
            )

            runState = .running
            let runner = PowerRunner(runtime: runtime, target: target)
            let session = try await runner.run(requests: requests)
            let payload = try PowerTextProgramModule.makePayload(
                workload: workload,
                workloadSHA256: workloadDefinition.sha256,
                session: session
            )
            let snapshot = session.targetAtStart
            let envelope = PowerEvidenceEnvelope(
                resultID: UUID(),
                createdAt: session.startedAt,
                program: Power2CandidateCatalog.program,
                target: Power2CandidateCatalog.target,
                runnerCertificateID:
                    Power2CandidateCatalog.runnerCertificateID,
                appRelease: appRelease,
                model: model.identity,
                runtime: session.runtimeIdentity,
                device: snapshot.device,
                environment: .init(
                    batteryLevelAtStart: snapshot.batteryLevel,
                    batteryStateAtStart: snapshot.batteryState,
                    lowPowerModeAtStart:
                        snapshot.lowPowerModeEnabled,
                    thermalStateAtStart: snapshot.thermalState,
                    thermalStateAtEnd: session.thermalStateAtEnd,
                    thermalAssistance: thermalAssistance
                ),
                artifacts: [],
                payload: payload
            )

            runState = .saving
            let stored = try await store.save(envelope: envelope)
            await reloadResults()
            selectedResultID = stored.id
            runState = .completed(stored.id)
            selectedTab = .results
        } catch is CancellationError {
            runState = .failed(
                "The run was cancelled before a complete evidence "
                    + "envelope could be saved."
            )
        } catch {
            runState = .failed(
                error.localizedDescription
            )
        }
    }
}

private enum RunError: LocalizedError {
    case incompleteBuildIdentity
    case physicalDeviceRequired

    var errorDescription: String? {
        switch self {
        case .incompleteBuildIdentity:
            "Power testing requires an eligible Certification or Official "
                + "build with an exact nonzero Git source revision."
        case .physicalDeviceRequired:
            "Power testing can run only on a physical iPhone."
        }
    }
}
