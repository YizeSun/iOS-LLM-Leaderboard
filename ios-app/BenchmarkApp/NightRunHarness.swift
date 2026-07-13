import Foundation
import HuggingFace
import Observation

private struct NightRunArtifactPreparation: Sendable {
    let cacheStateBeforePreparation: ModelPreparationEvidence.CacheState
    let downloadOccurred: Bool
}

private enum NightRunArtifactPreparationError: LocalizedError {
    case invalidRepositoryID(String)
    case cacheUnavailable
    case emptyManifest
    case incompleteAfterDownload

    var errorDescription: String? {
        switch self {
        case .invalidRepositoryID(let id):
            "Invalid Hugging Face repository ID: \(id)"
        case .cacheUnavailable:
            "The Hugging Face cache directory is unavailable."
        case .emptyManifest:
            "The pinned revision returned no required model files."
        case .incompleteAfterDownload:
            "The snapshot download returned before every required file was complete."
        }
    }
}

/// Branch-only cache preparation that preserves the underlying download error
/// for the Night Run UI. Formal Power preparation and result evidence remain
/// owned by `MLXSwiftRuntime.prepare(plan:)` after this step succeeds.
private actor NightRunArtifactPreparer {
    private static let requiredFileSuffixes = [
        ".safetensors", ".json", ".jinja",
    ]

    private let client = HuggingFace.HubClient()

    func prepare(
        profile: ProductionModelProfile
    ) async throws -> NightRunArtifactPreparation {
        let model = profile.planModelProfile
        guard let repository = HuggingFace.Repo.ID(
            rawValue: model.artifactId
        ) else {
            throw NightRunArtifactPreparationError.invalidRepositoryID(
                model.artifactId
            )
        }
        guard let cache = client.cache else {
            throw NightRunArtifactPreparationError.cacheUnavailable
        }

        let entries = try await client.listFiles(
            in: repository,
            revision: model.artifactRevision,
            recursive: true
        ).filter { entry in
            Self.requiredFileSuffixes.contains {
                entry.path.hasSuffix($0)
            }
        }
        guard !entries.isEmpty else {
            throw NightRunArtifactPreparationError.emptyManifest
        }

        let before = try Self.cacheState(
            entries: entries,
            cache: cache,
            repository: repository,
            revision: model.artifactRevision
        )
        guard before != .cached else {
            return NightRunArtifactPreparation(
                cacheStateBeforePreparation: before,
                downloadOccurred: false
            )
        }

        let patterns = Self.requiredFileSuffixes.map { "*\($0)" }
        _ = try await client.downloadSnapshot(
            of: repository,
            revision: model.artifactRevision,
            matching: patterns
        )
        let after = try Self.cacheState(
            entries: entries,
            cache: cache,
            repository: repository,
            revision: model.artifactRevision
        )
        guard after == .cached else {
            throw NightRunArtifactPreparationError.incompleteAfterDownload
        }
        return NightRunArtifactPreparation(
            cacheStateBeforePreparation: before,
            downloadOccurred: true
        )
    }

    private static func cacheState(
        entries: [HuggingFace.Git.TreeEntry],
        cache: HuggingFace.HubCache,
        repository: HuggingFace.Repo.ID,
        revision: String
    ) throws -> ModelPreparationEvidence.CacheState {
        let expectedFiles = Dictionary(
            uniqueKeysWithValues: entries.map { ($0.path, $0.size) }
        )
        var cachedFileSizes: [String: Int] = [:]
        for entry in entries {
            guard let url = cache.cachedFilePath(
                repo: repository,
                kind: .model,
                revision: revision,
                filename: entry.path
            ) else { continue }
            let size = try url.resolvingSymlinksInPath().resourceValues(
                forKeys: [.fileSizeKey]
            ).fileSize
            if let size {
                cachedFileSizes[entry.path] = size
            }
        }
        return ModelCacheVerification.classify(
            expectedFiles: expectedFiles,
            cachedFileSizes: cachedFileSizes
        )
    }
}

struct NightRunCell: Codable, Equatable, Identifiable, Sendable {
    enum Status: String, Codable, Sendable {
        case pending
        case preparing
        case waitingForNominalThermal
        case running
        case completed
        case failed
    }

    let id: String
    let modelProfileID: String
    let workloadID: String
    var status: Status
    var resultFilename: String?
    var message: String?
}

struct NightRunQueueSnapshot: Codable, Equatable, Sendable {
    static let formatVersion = 1

    let formatVersion: Int
    var selectedModelProfileIDs: [String]
    var cells: [NightRunCell]
    var updatedAt: Date

    init(
        selectedModelProfileIDs: [String],
        cells: [NightRunCell],
        updatedAt: Date = Date()
    ) {
        formatVersion = Self.formatVersion
        self.selectedModelProfileIDs = selectedModelProfileIDs
        self.cells = cells
        self.updatedAt = updatedAt
    }
}

enum NightRunPlan {
    static let defaultProfiles: [ProductionModelProfile] = [
        .lfm2OneTwoB,
        .exaone4OneTwoB,
        .bitnetTwoB,
        .llama32ThreeB,
    ]

    static let workloadOrder: [ProductionBenchmarkPlan] = [
        .shortInteraction,
        .sustainedGeneration,
    ]

    static func ordered(
        _ selected: Set<ProductionModelProfile>
    ) -> [ProductionModelProfile] {
        ProductionModelProfile.allCases.filter(selected.contains)
    }

    static func cells(
        for profiles: [ProductionModelProfile]
    ) -> [NightRunCell] {
        profiles.flatMap { profile in
            workloadOrder.map { workload in
                NightRunCell(
                    id: "\(profile.rawValue)::\(workload.workloadID)",
                    modelProfileID: profile.rawValue,
                    workloadID: workload.workloadID,
                    status: .pending,
                    resultFilename: nil,
                    message: nil
                )
            }
        }
    }
}

actor NightRunQueueStore {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = (try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )) ?? FileManager.default.temporaryDirectory
            self.fileURL = base
                .appending(path: "NightRunHarness", directoryHint: .isDirectory)
                .appending(path: "queue.json", directoryHint: .notDirectory)
        }
    }

    func load() throws -> NightRunQueueSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(
            NightRunQueueSnapshot.self,
            from: Data(contentsOf: fileURL)
        )
        guard snapshot.formatVersion == NightRunQueueSnapshot.formatVersion else {
            return nil
        }
        return snapshot
    }

    func save(_ snapshot: NightRunQueueSnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }

    func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}

struct NightRunLaunchGate {
    private static let downloadLaunchKey = "night-run-download-launch-id"
    private let defaults: UserDefaults
    let launchID: String

    init(
        defaults: UserDefaults = .standard,
        launchID: String = NightRunProcessIdentity.id
    ) {
        self.defaults = defaults
        self.launchID = launchID
    }

    var restartRequired: Bool {
        defaults.string(forKey: Self.downloadLaunchKey) == launchID
    }

    func recordDownload() {
        defaults.set(launchID, forKey: Self.downloadLaunchKey)
    }
}

private enum NightRunProcessIdentity {
    static let id = UUID().uuidString.lowercased()
}

@MainActor
@Observable
final class NightRunHarnessViewModel {
    enum Phase: Equatable {
        case idle
        case restoring
        case preparing
        case restartRequired
        case ready
        case waitingForNominalThermal
        case running
        case completed
        case stopped
        case failed
    }

    struct PreparationRow: Identifiable, Equatable {
        let id: String
        let title: String
        let cacheState: ModelPreparationEvidence.CacheState
        let downloaded: Bool
        let loaded: Bool
        let reasonCodes: [String]
        let diagnostic: String?
    }

    private(set) var phase: Phase = .idle
    private(set) var cells: [NightRunCell] = []
    private(set) var preparationRows: [PreparationRow] = []
    private(set) var availableStorageBytes: Int64?
    private(set) var statusText = "Prepare the selected model cache before starting."
    var selectedProfiles = Set(NightRunPlan.defaultProfiles)

    var isBusy: Bool {
        [.restoring, .preparing, .waitingForNominalThermal, .running]
            .contains(phase)
    }

    var completedCount: Int {
        cells.filter { $0.status == .completed }.count
    }

    var selectedArtifactSizeBytes: Int64 {
        selectedProfiles.reduce(into: 0) { total, profile in
            total += profile.planModelProfile.artifactRepositorySizeBytes
        }
    }

    var failedCount: Int {
        cells.filter { $0.status == .failed }.count
    }

    var restartRequired: Bool {
        launchGate.restartRequired || phase == .restartRequired
    }

    let runner: BenchmarkViewModel

    private let runtime: any ModelPreparingRuntime
    private let artifactPreparer = NightRunArtifactPreparer()
    private let queueStore: NightRunQueueStore
    private let launchGate: NightRunLaunchGate
    private var queueTask: Task<Void, Never>?

    init(
        runtime: any ModelPreparingRuntime = MLXSwiftRuntime(),
        queueStore: NightRunQueueStore = NightRunQueueStore(),
        launchGate: NightRunLaunchGate = NightRunLaunchGate()
    ) {
        self.runtime = runtime
        self.queueStore = queueStore
        self.launchGate = launchGate
        availableStorageBytes = Self.currentAvailableStorageBytes()
        runner = BenchmarkViewModel(runtime: runtime)
    }

    func isSelected(_ profile: ProductionModelProfile) -> Bool {
        selectedProfiles.contains(profile)
    }

    func setSelected(
        _ profile: ProductionModelProfile,
        selected: Bool
    ) {
        guard !isBusy else { return }
        if selected {
            selectedProfiles.insert(profile)
        } else {
            selectedProfiles.remove(profile)
        }
    }

    func restore() async {
        guard phase == .idle else { return }
        phase = .restoring
        do {
            if let snapshot = try await queueStore.load() {
                selectedProfiles = Set(snapshot.selectedModelProfileIDs.compactMap {
                    ProductionModelProfile(rawValue: $0)
                })
                cells = snapshot.cells
                if let runningIndex = cells.firstIndex(where: {
                    $0.status == .running
                }) {
                    await runner.recoverInterruptedSessionIfNeeded()
                    if let result = runner.latestPowerResult,
                       let resultURL = runner.resultFileURL,
                       cells[runningIndex].modelProfileID
                        == ProductionModelProfile.allCases.first(where: {
                            $0.planModelProfile.artifactId == result.model.artifactID
                        })?.rawValue,
                       cells[runningIndex].workloadID == result.execution.workloadID {
                        cells[runningIndex].status = .completed
                        cells[runningIndex].resultFilename = resultURL.lastPathComponent
                        cells[runningIndex].message = "Recovered after interruption."
                    } else {
                        cells[runningIndex].status = .failed
                        cells[runningIndex].message =
                            "Interrupted cell requires manual review before resuming."
                    }
                    try await persist()
                }
                phase = launchGate.restartRequired ? .restartRequired : .ready
                statusText = launchGate.restartRequired
                    ? "A model was downloaded in this App process. Fully close and relaunch before measuring."
                    : "Saved queue restored. Review it before resuming."
            } else {
                phase = .idle
            }
        } catch {
            phase = .failed
            statusText = "Queue recovery failed: \(error.localizedDescription)"
        }
    }

    func prepareSelectedModels() async {
        guard !isBusy, !selectedProfiles.isEmpty else { return }
        phase = .preparing
        preparationRows = []
        availableStorageBytes = Self.currentAvailableStorageBytes()
        let profiles = NightRunPlan.ordered(selectedProfiles)
        cells = NightRunPlan.cells(for: profiles)
        do {
            try await persist()
        } catch {
            phase = .failed
            statusText = "Could not save the queue: \(error.localizedDescription)"
            return
        }

        var downloadedAny = false
        for profile in profiles {
            if Task.isCancelled { break }
            statusText = "Preparing \(profile.planModelProfile.displayName)…"
            do {
                let loaded = try PilotPlanLoader.load(
                    resource: ProductionBenchmarkPlan.sustainedGeneration.rawValue,
                    modelProfile: profile
                )
                let artifactPreparation: NightRunArtifactPreparation
                do {
                    artifactPreparation = try await artifactPreparer.prepare(
                        profile: profile
                    )
                } catch {
                    preparationRows.append(.init(
                        id: profile.rawValue,
                        title: profile.planModelProfile.displayName,
                        cacheState: .unknown,
                        downloaded: false,
                        loaded: false,
                        reasonCodes: ["artifact_download_failed"],
                        diagnostic: Self.diagnosticDescription(error)
                    ))
                    continue
                }
                if artifactPreparation.downloadOccurred {
                    downloadedAny = true
                    launchGate.recordDownload()
                }
                let evidence = await runtime.prepare(plan: loaded.plan)
                downloadedAny = downloadedAny || evidence.downloadOccurredDuringSession
                if evidence.downloadOccurredDuringSession {
                    launchGate.recordDownload()
                }
                preparationRows.append(.init(
                    id: profile.rawValue,
                    title: profile.planModelProfile.displayName,
                    cacheState: artifactPreparation.cacheStateBeforePreparation,
                    downloaded: artifactPreparation.downloadOccurred
                        || evidence.downloadOccurredDuringSession,
                    loaded: evidence.modelLoadCompleted,
                    reasonCodes: evidence.reasonCodes,
                    diagnostic: nil
                ))
            } catch {
                preparationRows.append(.init(
                    id: profile.rawValue,
                    title: profile.planModelProfile.displayName,
                    cacheState: .unknown,
                    downloaded: false,
                    loaded: false,
                    reasonCodes: ["plan_load_failed"],
                    diagnostic: Self.diagnosticDescription(error)
                ))
            }
        }

        availableStorageBytes = Self.currentAvailableStorageBytes()

        if downloadedAny {
            phase = .restartRequired
            statusText = "Downloads completed. Fully close and relaunch the App before measuring."
        } else if preparationRows.allSatisfy(\.loaded) {
            phase = .ready
            statusText = "All selected artifacts were already cached and loaded successfully."
        } else {
            phase = .failed
            statusText = "At least one selected artifact could not be prepared. Review the rows below."
        }
    }

    func start() {
        guard !isBusy, !selectedProfiles.isEmpty else { return }
        guard phase == .ready else {
            statusText = "Prepare every selected model successfully before starting Night Run."
            return
        }
        guard !launchGate.restartRequired else {
            phase = .restartRequired
            statusText = "Fully close and relaunch after downloading models."
            return
        }
        if cells.isEmpty {
            cells = NightRunPlan.cells(
                for: NightRunPlan.ordered(selectedProfiles)
            )
        }
        queueTask = Task { [weak self] in
            await self?.executeQueue()
        }
    }

    func stop(reason: String = "Night Run stopped by the user.") {
        queueTask?.cancel()
        queueTask = nil
        if isBusy {
            phase = .stopped
            statusText = reason
        }
    }

    func appDidLeaveForeground() {
        guard isBusy else { return }
        stop(
            reason: "The App left the foreground. The active cell must be reviewed before resuming."
        )
    }

    func resetQueue() async {
        guard !isBusy else { return }
        do {
            try await queueStore.clear()
            cells = []
            preparationRows = []
            phase = .idle
            statusText = "Queue cleared. Prepare the selected model cache before starting."
        } catch {
            phase = .failed
            statusText = "Could not clear the queue: \(error.localizedDescription)"
        }
    }

    private func executeQueue() async {
        phase = .running
        statusText = "Night Run started. Keep this App active and the iPhone unplugged."
        do {
            try await persist()
        } catch {
            phase = .failed
            statusText = "Could not save the queue: \(error.localizedDescription)"
            return
        }

        while let index = cells.firstIndex(where: {
            $0.status == .pending || $0.status == .preparing
                || $0.status == .waitingForNominalThermal
        }) {
            if Task.isCancelled {
                phase = .stopped
                return
            }
            guard let profile = ProductionModelProfile(
                rawValue: cells[index].modelProfileID
            ), let workload = NightRunPlan.workloadOrder.first(where: {
                $0.workloadID == cells[index].workloadID
            }) else {
                cells[index].status = .failed
                cells[index].message = "Unknown model or workload identity."
                try? await persist()
                continue
            }

            cells[index].status = .preparing
            cells[index].message = nil
            statusText = "Loading \(profile.planModelProfile.displayName) for \(workload.workloadID)…"
            try? await persist()

            runner.selectModelProfile(profile)
            runner.selectBenchmarkPlan(workload)
            await runner.prepareModel()

            guard let preparation = runner.modelPreparation else {
                cells[index].status = .failed
                cells[index].message = "Model preparation produced no evidence."
                try? await persist()
                continue
            }
            if preparation.downloadOccurredDuringSession {
                launchGate.recordDownload()
                cells[index].status = .pending
                cells[index].message = "Downloaded during this process; restart required."
                phase = .restartRequired
                statusText = "A missing artifact was downloaded. Fully close and relaunch before measuring."
                try? await persist()
                return
            }
            guard preparation.eligibleForPerformanceMeasurement else {
                cells[index].status = .failed
                cells[index].message = preparation.reasonCodes.joined(separator: ", ")
                try? await persist()
                continue
            }

            guard await waitForAdmission(cellIndex: index) else {
                try? await persist()
                return
            }
            cells[index].status = .running
            statusText = "Running \(profile.planModelProfile.displayName) · \(workload.workloadID)…"
            try? await persist()

            await runner.run()
            if let result = runner.latestPowerResult,
               let resultURL = runner.resultFileURL,
               result.model.artifactID == profile.planModelProfile.artifactId,
               result.execution.workloadID == workload.workloadID {
                cells[index].status = .completed
                cells[index].resultFilename = resultURL.lastPathComponent
                cells[index].message = "Raw Power result saved."
                try? await persist()
            } else {
                cells[index].status = .failed
                cells[index].message = runner.statusText
                phase = .stopped
                statusText = "The runner did not export the active cell. Review its checkpoint before continuing."
                try? await persist()
                return
            }
        }

        phase = .completed
        statusText = "Night Run finished: \(completedCount) result files saved, \(failedCount) cells failed before export."
        try? await persist()
        queueTask = nil
    }

    private func waitForAdmission(cellIndex: Int) async -> Bool {
        while !Task.isCancelled {
            runner.refreshThermalState()
            if runner.admissionReasonCodes.isEmpty,
               runner.powerContractError == nil {
                phase = .running
                return true
            }
            let reasons = runner.admissionReasonCodes
            if reasons == ["initial_thermal_state_not_nominal"] {
                phase = .waitingForNominalThermal
                cells[cellIndex].status = .waitingForNominalThermal
                statusText = "Waiting for nominal thermal state before the next independent cell…"
                try? await persist()
                try? await Task.sleep(for: .seconds(30))
                continue
            }
            cells[cellIndex].status = .pending
            cells[cellIndex].message = (reasons + [runner.powerContractError]
                .compactMap { $0 }).joined(separator: ", ")
            phase = .stopped
            statusText = "Environment admission failed: \(cells[cellIndex].message ?? "unknown reason")"
            return false
        }
        phase = .stopped
        return false
    }

    private func persist() async throws {
        try await queueStore.save(.init(
            selectedModelProfileIDs: NightRunPlan.ordered(selectedProfiles)
                .map(\.rawValue),
            cells: cells,
            updatedAt: Date()
        ))
    }

    private static func currentAvailableStorageBytes() -> Int64? {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        return try? home.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        ).volumeAvailableCapacityForImportantUsage
    }

    private static func diagnosticDescription(_ error: Error) -> String {
        let localized = error.localizedDescription
        let reflected = String(reflecting: error)
        let combined = reflected.contains(localized)
            ? reflected
            : "\(localized) · \(reflected)"
        return String(combined.prefix(1_000))
    }
}
