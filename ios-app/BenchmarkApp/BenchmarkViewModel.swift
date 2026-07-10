import Foundation
import Observation

@MainActor
@Observable
final class BenchmarkViewModel {
    enum Phase: Equatable {
        case ready
        case running
        case completed(measuredAttempts: Int, failedAttempts: Int)
        case failed(message: String)
    }

    private(set) var phase: Phase = .ready
    private(set) var result: PilotResultBundle?
    private(set) var resultFileURL: URL?
    private(set) var currentThermalState = SystemMeasurements.thermalState
    private(set) var debuggerAttached = DebuggerStatus.isAttached

    var canRun: Bool {
        phase != .running
            && !debuggerAttached
            && currentThermalState == "nominal"
    }

    var statusText: String {
        if debuggerAttached {
            return "Debugger attached. In Edit Scheme → Run → Info, turn off Debug executable before measuring."
        }
        if currentThermalState != "nominal" {
            return "Wait for this iPhone to cool to nominal, then pull down to refresh."
        }
        return switch phase {
        case .ready:
            "Ready. The first run downloads and caches the pinned model."
        case .running:
            "Loading the model, then running 1 warm-up and 5 measured attempts…"
        case .completed(let measuredAttempts, let failedAttempts):
            "Saved \(measuredAttempts) measured records; \(failedAttempts) did not complete."
        case .failed(let message):
            "Run failed: \(message)"
        }
    }

    private let runtime = MLXSwiftRuntime()
    private let resultStore = ResultStore()

    func run() async {
        debuggerAttached = DebuggerStatus.isAttached
        guard canRun else { return }
        phase = .running
        currentThermalState = SystemMeasurements.thermalState

        do {
            let prompt = try Self.loadPrompt()
            let session = await BenchmarkRunner(
                runtime: runtime,
                procedure: .pilot
            ).run(prompt: prompt)

            guard !session.measuredAttempts.isEmpty else {
                let message = session.attempts.first.map(Self.failureMessage)
                    ?? "No attempts were recorded."
                phase = .failed(message: message)
                return
            }

            let failures = session.measuredAttempts.filter { attempt in
                if case .completed = attempt.outcome { return false }
                return true
            }.count
            let bundle = PilotResultBundle.make(
                session: session,
                environment: .current
            )
            resultFileURL = try await resultStore.save(bundle)
            result = bundle
            currentThermalState = bundle.summary.finalThermalState
            phase = .completed(
                measuredAttempts: session.measuredAttempts.count,
                failedAttempts: failures
            )
        } catch {
            currentThermalState = SystemMeasurements.thermalState
            phase = .failed(message: String(describing: error))
        }
    }

    func refreshThermalState() {
        currentThermalState = SystemMeasurements.thermalState
        debuggerAttached = DebuggerStatus.isAttached
    }

    func metricText(_ value: Double?, unit: String) -> String {
        guard let value else { return "Unavailable" }
        return "\(value.formatted(.number.precision(.fractionLength(1)))) \(unit)"
    }

    func percentText(_ value: Double?) -> String {
        guard let value else { return "Unavailable" }
        return value.formatted(
            .number
                .sign(strategy: .always())
                .precision(.fractionLength(1))
        ) + "%"
    }

    var measuredAttemptRecords: [PilotResultBundle.Attempt] {
        result?.attempts.filter { $0.role == "measured" } ?? []
    }

    var warmupAttemptRecord: PilotResultBundle.Attempt? {
        result?.attempts.first { $0.role == "warmup" }
    }

    private static func loadPrompt() throws -> String {
        guard let url = Bundle.main.url(
            forResource: "suite-b-pilot-001-prompt",
            withExtension: "txt"
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func failureMessage(_ attempt: BenchmarkAttempt) -> String {
        switch attempt.outcome {
        case .completed:
            "The runner stopped before measured attempts."
        case .failed(let message):
            message
        case .notRun(let reason):
            reason
        }
    }
}
