import Foundation

struct PilotResultBundle: Codable, Sendable {
    let schemaVersion: String
    let resultID: String
    let createdAt: Date
    let officialResultEligible: Bool
    let plan: PlanIdentity
    let workload: WorkloadIdentity
    let measurementMode: MeasurementModeIdentity
    let generationConfiguration: GenerationConfiguration
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
        let v2ProfileMapping: String
    }

    struct WorkloadIdentity: Codable, Sendable {
        let id: String
        let version: String
        let category: String
        let promptSHA256: String
    }

    struct MeasurementModeIdentity: Codable, Sendable {
        let id: String
        let timingBoundaryVersion: String
        let pipelineTTFTStart: String
        let pipelineTTFTEnd: String
        let userVisibleTTFTAvailable: Bool
        let prefillSource: String
        let decodeFormula: String
        let memoryMetric: String
        let memorySamplingIntervalMilliseconds: Int
    }

    struct GenerationConfiguration: Codable, Sendable {
        enum CodingKeys: String, CodingKey {
            case samplingEnabled
            case temperature
            case topP
            case topK
            case seed
            case repetitionPenalty
            case thinkingMode
            case chatTemplateIdentity
            case includeStopTokenInRawEvents
            case outputTokenLimit
            case contextPolicy
            case modelLoadPolicy
            case kvCachePolicy
        }

        let samplingEnabled: Bool
        let temperature: Double
        let topP: Double?
        let topK: Int?
        let seed: UInt64?
        let repetitionPenalty: Double?
        let thinkingMode: String
        let chatTemplateIdentity: String
        let includeStopTokenInRawEvents: Bool
        let outputTokenLimit: Int
        let contextPolicy: String
        let modelLoadPolicy: String
        let kvCachePolicy: String

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(samplingEnabled, forKey: .samplingEnabled)
            try container.encode(temperature, forKey: .temperature)
            if let topP {
                try container.encode(topP, forKey: .topP)
            } else {
                try container.encodeNil(forKey: .topP)
            }
            if let topK {
                try container.encode(topK, forKey: .topK)
            } else {
                try container.encodeNil(forKey: .topK)
            }
            if let seed {
                try container.encode(seed, forKey: .seed)
            } else {
                try container.encodeNil(forKey: .seed)
            }
            if let repetitionPenalty {
                try container.encode(repetitionPenalty, forKey: .repetitionPenalty)
            } else {
                try container.encodeNil(forKey: .repetitionPenalty)
            }
            try container.encode(thinkingMode, forKey: .thinkingMode)
            try container.encode(chatTemplateIdentity, forKey: .chatTemplateIdentity)
            try container.encode(
                includeStopTokenInRawEvents,
                forKey: .includeStopTokenInRawEvents
            )
            try container.encode(outputTokenLimit, forKey: .outputTokenLimit)
            try container.encode(contextPolicy, forKey: .contextPolicy)
            try container.encode(modelLoadPolicy, forKey: .modelLoadPolicy)
            try container.encode(kvCachePolicy, forKey: .kvCachePolicy)
        }
    }

    struct ModelIdentity: Codable, Sendable {
        enum CodingKeys: String, CodingKey {
            case displayName
            case baseModelID
            case artifactID
            case artifactRevision
            case quantization
            case modelFormat
            case artifactContentHash
        }

        let displayName: String
        let baseModelID: String
        let artifactID: String
        let artifactRevision: String
        let quantization: String
        let modelFormat: String
        let artifactContentHash: String?

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(displayName, forKey: .displayName)
            try container.encode(baseModelID, forKey: .baseModelID)
            try container.encode(artifactID, forKey: .artifactID)
            try container.encode(artifactRevision, forKey: .artifactRevision)
            try container.encode(quantization, forKey: .quantization)
            try container.encode(modelFormat, forKey: .modelFormat)
            if let artifactContentHash {
                try container.encode(artifactContentHash, forKey: .artifactContentHash)
            } else {
                try container.encodeNil(forKey: .artifactContentHash)
            }
        }
    }

    struct RuntimeIdentity: Codable, Sendable {
        let name: String
        let version: String
        let resolvedRevision: String
        let backend: String
        let mlxSwiftVersion: String
        let mlxSwiftRevision: String
        let downloaderPackage: String
        let tokenizerPackage: String
    }

    struct DeviceIdentity: Codable, Sendable {
        enum CodingKeys: String, CodingKey {
            case displayName
            case machineIdentifier
            case systemName
            case systemVersion
            case systemBuild
            case debuggerAttached
            case buildConfiguration
            case appVersion
            case appBuild
            case appSourceCommit
            case lowPowerModeEnabled
            case batteryLevelPercent
            case batteryState
        }

        let displayName: String
        let machineIdentifier: String
        let systemName: String
        let systemVersion: String
        let systemBuild: String
        let debuggerAttached: Bool
        let buildConfiguration: String
        let appVersion: String
        let appBuild: String
        let appSourceCommit: String?
        let lowPowerModeEnabled: Bool
        let batteryLevelPercent: Double?
        let batteryState: String

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(displayName, forKey: .displayName)
            try container.encode(machineIdentifier, forKey: .machineIdentifier)
            try container.encode(systemName, forKey: .systemName)
            try container.encode(systemVersion, forKey: .systemVersion)
            try container.encode(systemBuild, forKey: .systemBuild)
            try container.encode(debuggerAttached, forKey: .debuggerAttached)
            try container.encode(buildConfiguration, forKey: .buildConfiguration)
            try container.encode(appVersion, forKey: .appVersion)
            try container.encode(appBuild, forKey: .appBuild)
            if let appSourceCommit {
                try container.encode(appSourceCommit, forKey: .appSourceCommit)
            } else {
                try container.encodeNil(forKey: .appSourceCommit)
            }
            try container.encode(lowPowerModeEnabled, forKey: .lowPowerModeEnabled)
            if let batteryLevelPercent {
                try container.encode(batteryLevelPercent, forKey: .batteryLevelPercent)
            } else {
                try container.encodeNil(forKey: .batteryLevelPercent)
            }
            try container.encode(batteryState, forKey: .batteryState)
        }
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
            buildConfiguration: String,
            lowPowerModeEnabled: Bool,
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
            if buildConfiguration != "Release" {
                sessionReasons.append("non_release_build")
            }
            if lowPowerModeEnabled {
                sessionReasons.append("low_power_mode_enabled")
            }
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
            schemaVersion: "suite-b-pilot-bundle-0.4",
            resultID: UUID().uuidString.lowercased(),
            createdAt: Date(),
            officialResultEligible: false,
            plan: PlanIdentity(
                id: "suite-b-pilot-001",
                version: "0.2.0",
                promptSHA256: "b865ad1a1993bfd7bf097b85f7c5585e44f1384fa291b9c05426c6051caba996",
                warmupRuns: 1,
                measuredRuns: 5,
                outputTokenLimit: 512,
                v2ProfileMapping: "b-pipe-001-sustained-generation@0.1.0-draft"
            ),
            workload: WorkloadIdentity(
                id: "suite-b-pilot-001-fixed-generation",
                version: "1.0",
                category: "pipeline",
                promptSHA256: "b865ad1a1993bfd7bf097b85f7c5585e44f1384fa291b9c05426c6051caba996"
            ),
            measurementMode: MeasurementModeIdentity(
                id: "b-mode-sustained-no-rest-v1",
                timingBoundaryVersion: "mlx-pilot-pipeline-boundaries-1",
                pipelineTTFTStart: "after_prompt_preparation_before_generate_tokens_task",
                pipelineTTFTEnd: "first_raw_token_received_by_adapter",
                userVisibleTTFTAvailable: false,
                prefillSource: "mlx_generate_completion_info_prompt_time",
                decodeFormula: "(raw_token_count-1)/(last_raw_token_time-first_raw_token_time)",
                memoryMetric: "TASK_VM_INFO.phys_footprint",
                memorySamplingIntervalMilliseconds: 50
            ),
            generationConfiguration: GenerationConfiguration(
                samplingEnabled: false,
                temperature: 0,
                topP: nil,
                topK: nil,
                seed: nil,
                repetitionPenalty: nil,
                thinkingMode: "model-default",
                chatTemplateIdentity: "artifact-tokenizer-config",
                includeStopTokenInRawEvents: false,
                outputTokenLimit: 512,
                contextPolicy: "new-context-for-each-generation",
                modelLoadPolicy: "load-once-before-warmup",
                kvCachePolicy: "new-cache-for-each-generation"
            ),
            model: ModelIdentity(
                displayName: "Qwen3 0.6B",
                baseModelID: "Qwen/Qwen3-0.6B",
                artifactID: "mlx-community/Qwen3-0.6B-4bit",
                artifactRevision: "73e3e38d981303bc594367cd910ea6eb48349da8",
                quantization: "4-bit",
                modelFormat: "MLX Safetensors",
                artifactContentHash: nil
            ),
            runtime: RuntimeIdentity(
                name: "MLX Swift LM",
                version: "3.31.4",
                resolvedRevision: "bd4b7434e6bdb588c7ef55706ff8904cb7fd4c57",
                backend: "MLX/Metal",
                mlxSwiftVersion: "0.31.6",
                mlxSwiftRevision: "0bb916c67f4b9e5c682cbe02a42c701c93ab5021",
                downloaderPackage: "swift-huggingface 0.9.0",
                tokenizerPackage: "swift-transformers 1.3.0"
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
                appBuild: environment.appBuild,
                appSourceCommit: environment.appSourceCommit,
                lowPowerModeEnabled: environment.lowPowerModeEnabled,
                batteryLevelPercent: environment.batteryLevelPercent,
                batteryState: environment.batteryState
            ),
            eligibility: .evaluate(
                attempts: attemptRecords,
                debuggerAttached: environment.debuggerAttached,
                buildConfiguration: environment.buildConfiguration,
                lowPowerModeEnabled: environment.lowPowerModeEnabled,
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
