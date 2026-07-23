import Foundation
import Observation
import PowerResultsStore

@MainActor
@Observable
final class PowerAppModel {
    enum SelectedTab: Hashable {
        case test
        case results
    }

    var selectedTab: SelectedTab = .test
    var results: [StoredPowerResult] = []
    var selectedResultID: UUID?
    var resultLoadError: String?
    var isLoadingResults = false

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
        Power2CandidateIdentity.appReleaseAvailable
            && Power2CandidateIdentity.publicIntakeOpen
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
}
