import Foundation

struct PilotResultBundle: Codable, Sendable {
    let schemaVersion: String
    let resultID: String
    let createdAt: Date
    let officialResultEligible: Bool
    let plan: PlanIdentity
    let model: ModelIdentity
    let runtime: RuntimeIdentity
    let device: DeviceIdentity
    let eligibility: Eligibility
    let summary: Summary
    let attempts: [Attempt]

    struct PlanIdentity: Codable, Sendable {
        let id: String
        let version: String
        let promptSHA256: String
        let warmupRuns: Int
        let measuredRuns: Int
        let outputTokenLimit: Int
    }

    struct ModelIdentity: Codable, Sendable {
        let displayName: String
        let artifactID: String
        let artifactRevision: String
        let quantization: String
    }

    struct RuntimeIdentity: Codable, Sendable {
        let name: String
        let version: String
        let resolvedRevision: String
        let backend: String
    }

    struct DeviceIdentity: Codable, Sendable {
        let displayName: String
        let machineIdentifier: String
        let systemName: String
        let systemVersion: String
        let systemBuild: String
        let debuggerAttached: Bool
        let buildConfiguration: String
        let appVersion: String
        let appBuild: String
    }

    struct Eligibility: Codable, Sendable, Equatable {
        let sessionValidity: Decision
        let coldPerformance: Decision
        let sustainedPerformance: Decision
        let thermalStability: Decision
        let officialLeaderboard: Decision

        struct Decision: Codable, Sendable, Equatable {
            let eligible: Bool
            let reasonCodes: [String]
        }

        static func evaluate(
            attempts: [Attempt],
            debuggerAttached: Bool,
            plannedMeasuredRuns: Int
        ) -> Eligibility {
            let measured = attempts.filter { $0.role == "measured" }
            let successful = measured.filter { $0.outcome == "completed" }
            let initialThermal = attempts.first?.thermalStateBefore
            let startsNominal = initialThermal == "nominal"
            let hasAllAttemptRecords = measured.count == plannedMeasuredRuns
            let hasNotRun = measured.contains { $0.outcome == "notRun" }
            let hasThreeSuccessful = successful.count >= 3
            let nominalMeasured = successful.filter {
                $0.thermalStateBefore == "nominal"
                    && $0.thermalStateAfter == "nominal"
            }

            var sessionReasons: [String] = []
            if debuggerAttached { sessionReasons.append("debugger_attached") }
            if !startsNominal {
                sessionReasons.append("initial_thermal_state_not_nominal")
            }
            if !hasAllAttemptRecords {
                sessionReasons.append("incomplete_attempt_records")
            }
            if !hasThreeSuccessful {
                sessionReasons.append("insufficient_successful_measured_runs")
            }
            if hasNotRun { sessionReasons.append("planned_attempt_not_run") }

            var coldReasons: [String] = []
            if !startsNominal {
                coldReasons.append("initial_thermal_state_not_nominal")
            }
            if nominalMeasured.isEmpty {
                coldReasons.append("no_nominal_measured_run")
            }

            var sustainedReasons: [String] = []
            if !startsNominal {
                sustainedReasons.append("initial_thermal_state_not_nominal")
            }
            if !hasThreeSuccessful {
                sustainedReasons.append("insufficient_successful_measured_runs")
            }
            if hasNotRun { sustainedReasons.append("sequence_stopped_early") }

            var thermalReasons: [String] = []
            if !hasThreeSuccessful {
                thermalReasons.append("insufficient_successful_measured_runs")
            }
            if measured.contains(where: {
                $0.thermalStateBefore == "unknown"
                    || $0.thermalStateAfter == "unknown"
            }) {
                thermalReasons.append("thermal_state_unavailable")
            }

            return Eligibility(
                sessionValidity: Decision(
                    eligible: sessionReasons.isEmpty,
                    reasonCodes: sessionReasons
                ),
                coldPerformance: Decision(
                    eligible: coldReasons.isEmpty,
                    reasonCodes: coldReasons
                ),
                sustainedPerformance: Decision(
                    eligible: sustainedReasons.isEmpty,
                    reasonCodes: sustainedReasons
                ),
                thermalStability: Decision(
                    eligible: thermalReasons.isEmpty,
                    reasonCodes: thermalReasons
                ),
                officialLeaderboard: Decision(
                    eligible: false,
                    reasonCodes: ["pilot_protocol_not_official"]
                )
            )
        }
    }

    struct Summary: Codable, Sendable {
        let successfulMeasuredRuns: Int
        let failedMeasuredRuns: Int
        let medianTTFTMilliseconds: Double?
        let medianPrefillTokensPerSecond: Double?
        let medianDecodeTokensPerSecond: Double?
        let medianPeakMemoryMegabytes: Double?
        let finalThermalState: String
        let degradation: Degradation
    }

    struct Degradation: Codable, Sendable {
        let firstMeasuredRunIndex: Int?
        let lastMeasuredRunIndex: Int?
        let decodePercentChange: Double?
        let ttftPercentChange: Double?
        let prefillPercentChange: Double?

        static func calculate(first: Attempt?, last: Attempt?) -> Degradation {
            Degradation(
                firstMeasuredRunIndex: first?.runIndex,
                lastMeasuredRunIndex: last?.runIndex,
                decodePercentChange: percentChange(
                    from: first?.metrics.decodeTokensPerSecond,
                    to: last?.metrics.decodeTokensPerSecond
                ),
                ttftPercentChange: percentChange(
                    from: first?.metrics.ttftMilliseconds,
                    to: last?.metrics.ttftMilliseconds
                ),
                prefillPercentChange: percentChange(
                    from: first?.metrics.prefillTokensPerSecond,
                    to: last?.metrics.prefillTokensPerSecond
                )
            )
        }

        private static func percentChange(from first: Double?, to last: Double?) -> Double? {
            guard let first, let last, first != 0 else { return nil }
            return (last / first - 1) * 100
        }
    }

    struct Attempt: Codable, Sendable {
        let runIndex: Int
        let role: String
        let outcome: String
        let errorMessage: String?
        let promptTokenCount: Int?
        let outputTokenCount: Int?
        let stopReason: String?
        let thermalStateBefore: String
        let thermalStateAfter: String
        let memorySamplingIntervalMilliseconds: Int
        let metrics: AttemptMetrics
        let tokenEvents: [RuntimeToken]
    }

    @MainActor
    static func make(
        session: BenchmarkSession,
        environment: DeviceEnvironment
    ) -> PilotResultBundle {
        let attemptRecords = session.attempts.map { attempt in
            let generation: RuntimeGenerationResult?
            let outcome: String
            let error: String?
            switch attempt.outcome {
            case .completed(let result):
                generation = result
                outcome = "completed"
                error = nil
            case .failed(let message):
                generation = nil
                outcome = "failed"
                error = message
            case .notRun(let reason):
                generation = nil
                outcome = "notRun"
                error = reason
            }
            return Attempt(
                runIndex: attempt.index,
                role: attempt.role.rawValue,
                outcome: outcome,
                errorMessage: error,
                promptTokenCount: generation?.promptTokenCount,
                outputTokenCount: generation?.outputTokenCount,
                stopReason: generation?.stopReason.rawValue,
                thermalStateBefore: attempt.thermalStateBefore,
                thermalStateAfter: attempt.thermalStateAfter,
                memorySamplingIntervalMilliseconds: 50,
                metrics: .calculate(for: attempt),
                tokenEvents: attempt.tokens
            )
        }

        let measured = zip(session.measuredAttempts, attemptRecords.filter {
            $0.role == BenchmarkAttempt.Role.measured.rawValue
        })
        let successful = measured.filter { pair in
            if case .completed = pair.0.outcome { return true }
            return false
        }.map(\.1)
        let failedCount = session.measuredAttempts.count - successful.count

        return PilotResultBundle(
            schemaVersion: "suite-b-pilot-bundle-0.3",
            resultID: UUID().uuidString.lowercased(),
            createdAt: Date(),
            officialResultEligible: false,
            plan: PlanIdentity(
                id: "suite-b-pilot-001",
                version: "0.1.0",
                promptSHA256: "b865ad1a1993bfd7bf097b85f7c5585e44f1384fa291b9c05426c6051caba996",
                warmupRuns: 1,
                measuredRuns: 5,
                outputTokenLimit: 512
            ),
            model: ModelIdentity(
                displayName: "Qwen3 0.6B",
                artifactID: "mlx-community/Qwen3-0.6B-4bit",
                artifactRevision: "73e3e38d981303bc594367cd910ea6eb48349da8",
                quantization: "4-bit"
            ),
            runtime: RuntimeIdentity(
                name: "MLX Swift LM",
                version: "3.31.4",
                resolvedRevision: "bd4b7434e6bdb588c7ef55706ff8904cb7fd4c57",
                backend: "MLX/Metal"
            ),
            device: DeviceIdentity(
                displayName: environment.deviceDescription,
                machineIdentifier: environment.modelIdentifier,
                systemName: environment.systemName,
                systemVersion: environment.systemVersion,
                systemBuild: environment.systemBuild,
                debuggerAttached: environment.debuggerAttached,
                buildConfiguration: environment.buildConfiguration,
                appVersion: environment.appVersion,
                appBuild: environment.appBuild
            ),
            eligibility: .evaluate(
                attempts: attemptRecords,
                debuggerAttached: environment.debuggerAttached,
                plannedMeasuredRuns: 5
            ),
            summary: Summary(
                successfulMeasuredRuns: successful.count,
                failedMeasuredRuns: failedCount,
                medianTTFTMilliseconds: AttemptMetrics.median(
                    successful.map { $0.metrics.ttftMilliseconds }
                ),
                medianPrefillTokensPerSecond: AttemptMetrics.median(
                    successful.map { $0.metrics.prefillTokensPerSecond }
                ),
                medianDecodeTokensPerSecond: AttemptMetrics.median(
                    successful.map { $0.metrics.decodeTokensPerSecond }
                ),
                medianPeakMemoryMegabytes: AttemptMetrics.median(
                    successful.map { $0.metrics.peakMemoryMegabytes }
                ),
                finalThermalState: attemptRecords.last?.thermalStateAfter
                    ?? environment.thermalState,
                degradation: .calculate(
                    first: successful.first,
                    last: successful.last
                )
            ),
            attempts: attemptRecords
        )
    }
}
