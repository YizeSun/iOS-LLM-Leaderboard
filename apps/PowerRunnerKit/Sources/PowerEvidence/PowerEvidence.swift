import Foundation

public enum PowerEvidenceConstants {
    public static let envelopeSchemaVersion =
        "power-evidence-envelope-1.0.0-draft.1"
    public static let textPayloadSchemaVersion =
        "power-text-generation-payload-1.0.0-draft.1"
    public static let productID = "power"
    public static let continuousClockID = "continuous-clock"
}

public enum PowerThermalState: String, Codable, Sendable, CaseIterable {
    case nominal
    case fair
    case serious
    case critical
    case unknown
}

public enum PowerBatteryState: String, Codable, Sendable, CaseIterable {
    case unplugged
    case charging
    case full
    case unknown
}

public enum PowerThermalAssistance: String, Codable, Sendable, CaseIterable {
    case none
    case deliberateCooling = "deliberate-cooling"
    case deliberateHeating = "deliberate-heating"
    case otherAssisted = "other-assisted"
    case unknown
}

public enum PowerAttemptPhase: String, Codable, Sendable {
    case warmup
    case measured
}

public enum PowerAttemptOutcome: String, Codable, Sendable {
    case succeeded
    case failed
    case cancelled
    case oom
    case notRun = "not-run"
}

public struct PowerVersionedIdentity: Codable, Sendable, Equatable {
    public let id: String
    public let version: String
    public let manifestSHA256: String

    public init(id: String, version: String, manifestSHA256: String) {
        self.id = id
        self.version = version
        self.manifestSHA256 = manifestSHA256
    }
}

public struct PowerAppReleaseIdentity: Codable, Sendable, Equatable {
    public let version: String
    public let build: String
    public let sourceRevision: String
    public let embeddedMeasurementStackSHA256: String

    public init(
        version: String,
        build: String,
        sourceRevision: String,
        embeddedMeasurementStackSHA256: String
    ) {
        self.version = version
        self.build = build
        self.sourceRevision = sourceRevision
        self.embeddedMeasurementStackSHA256 =
            embeddedMeasurementStackSHA256
    }
}

public struct PowerModelIdentity: Codable, Sendable, Equatable {
    public let registryEntryID: String
    public let registryEntrySHA256: String
    public let artifactID: String
    public let artifactRevision: String
    public let parameterCount: Int64
    public let quantization: String
    public let format: String

    public init(
        registryEntryID: String,
        registryEntrySHA256: String,
        artifactID: String,
        artifactRevision: String,
        parameterCount: Int64,
        quantization: String,
        format: String
    ) {
        self.registryEntryID = registryEntryID
        self.registryEntrySHA256 = registryEntrySHA256
        self.artifactID = artifactID
        self.artifactRevision = artifactRevision
        self.parameterCount = parameterCount
        self.quantization = quantization
        self.format = format
    }
}

public struct PowerRuntimeIdentity: Codable, Sendable, Equatable {
    public let name: String
    public let version: String
    public let resolvedRevision: String
    public let backend: String
    public let configuration: [String: JSONValue]

    public init(
        name: String,
        version: String,
        resolvedRevision: String,
        backend: String,
        configuration: [String: JSONValue]
    ) {
        self.name = name
        self.version = version
        self.resolvedRevision = resolvedRevision
        self.backend = backend
        self.configuration = configuration
    }
}

public struct PowerDeviceIdentity: Codable, Sendable, Equatable {
    public let machineIdentifier: String
    public let osVersion: String
    public let osBuild: String

    public init(
        machineIdentifier: String,
        osVersion: String,
        osBuild: String
    ) {
        self.machineIdentifier = machineIdentifier
        self.osVersion = osVersion
        self.osBuild = osBuild
    }
}

public struct PowerEnvironment: Codable, Sendable, Equatable {
    public let batteryLevelAtStart: Double
    public let batteryStateAtStart: PowerBatteryState
    public let lowPowerModeAtStart: Bool
    public let thermalStateAtStart: PowerThermalState
    public let thermalStateAtEnd: PowerThermalState
    public let thermalAssistance: PowerThermalAssistance

    public init(
        batteryLevelAtStart: Double,
        batteryStateAtStart: PowerBatteryState,
        lowPowerModeAtStart: Bool,
        thermalStateAtStart: PowerThermalState,
        thermalStateAtEnd: PowerThermalState,
        thermalAssistance: PowerThermalAssistance
    ) {
        self.batteryLevelAtStart = batteryLevelAtStart
        self.batteryStateAtStart = batteryStateAtStart
        self.lowPowerModeAtStart = lowPowerModeAtStart
        self.thermalStateAtStart = thermalStateAtStart
        self.thermalStateAtEnd = thermalStateAtEnd
        self.thermalAssistance = thermalAssistance
    }
}

public struct PowerArtifactIdentity: Codable, Sendable, Equatable {
    public let path: String
    public let sha256: String
    public let mediaType: String
    public let byteCount: Int64

    public init(
        path: String,
        sha256: String,
        mediaType: String,
        byteCount: Int64
    ) {
        self.path = path
        self.sha256 = sha256
        self.mediaType = mediaType
        self.byteCount = byteCount
    }
}

public struct PowerWorkloadIdentity: Codable, Sendable, Equatable {
    public let id: String
    public let version: String
    public let sha256: String

    public init(id: String, version: String, sha256: String) {
        self.id = id
        self.version = version
        self.sha256 = sha256
    }
}

public struct PowerInferenceConfiguration: Codable, Sendable, Equatable {
    public let sampling: Bool
    public let temperature: Double
    public let topP: Double
    public let topK: Int
    public let seed: Int
    public let maximumOutputTokens: Int
    public let reasoningMode: String
    public let newContextPerAttempt: Bool
    public let newKVCachePerAttempt: Bool

    public init(
        sampling: Bool,
        temperature: Double,
        topP: Double,
        topK: Int,
        seed: Int,
        maximumOutputTokens: Int,
        reasoningMode: String,
        newContextPerAttempt: Bool,
        newKVCachePerAttempt: Bool
    ) {
        self.sampling = sampling
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.seed = seed
        self.maximumOutputTokens = maximumOutputTokens
        self.reasoningMode = reasoningMode
        self.newContextPerAttempt = newContextPerAttempt
        self.newKVCachePerAttempt = newKVCachePerAttempt
    }
}

public struct PowerMonotonicMeasurement: Codable, Sendable, Equatable {
    public let clock: String
    public let requestAcceptedNanoseconds: UInt64
    public let firstTokenNanoseconds: UInt64?
    public let firstRenderableNanoseconds: UInt64?
    public let completedNanoseconds: UInt64?
    public let promptEvaluationNanoseconds: UInt64?
    public let decodeNanoseconds: UInt64?

    public init(
        clock: String = PowerEvidenceConstants.continuousClockID,
        requestAcceptedNanoseconds: UInt64,
        firstTokenNanoseconds: UInt64?,
        firstRenderableNanoseconds: UInt64?,
        completedNanoseconds: UInt64?,
        promptEvaluationNanoseconds: UInt64?,
        decodeNanoseconds: UInt64?
    ) {
        self.clock = clock
        self.requestAcceptedNanoseconds = requestAcceptedNanoseconds
        self.firstTokenNanoseconds = firstTokenNanoseconds
        self.firstRenderableNanoseconds = firstRenderableNanoseconds
        self.completedNanoseconds = completedNanoseconds
        self.promptEvaluationNanoseconds = promptEvaluationNanoseconds
        self.decodeNanoseconds = decodeNanoseconds
    }

    private enum CodingKeys: String, CodingKey {
        case clock
        case requestAcceptedNanoseconds
        case firstTokenNanoseconds
        case firstRenderableNanoseconds
        case completedNanoseconds
        case promptEvaluationNanoseconds
        case decodeNanoseconds
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(clock, forKey: .clock)
        try container.encode(
            requestAcceptedNanoseconds,
            forKey: .requestAcceptedNanoseconds
        )
        try container.encode(
            firstTokenNanoseconds,
            forKey: .firstTokenNanoseconds
        )
        try container.encode(
            firstRenderableNanoseconds,
            forKey: .firstRenderableNanoseconds
        )
        try container.encode(
            completedNanoseconds,
            forKey: .completedNanoseconds
        )
        try container.encode(
            promptEvaluationNanoseconds,
            forKey: .promptEvaluationNanoseconds
        )
        try container.encode(
            decodeNanoseconds,
            forKey: .decodeNanoseconds
        )
    }
}

public struct PowerTokenCounts: Codable, Sendable, Equatable {
    public let input: Int
    public let output: Int

    public init(input: Int, output: Int) {
        self.input = input
        self.output = output
    }
}

public struct PowerTokenEvent: Codable, Sendable, Equatable {
    public let index: Int
    public let tokenID: Int
    public let receivedNanoseconds: UInt64
    public let decodedAtNanoseconds: UInt64?
    public let decodedPrefix: String?
    public let isSpecial: Bool?
    public let isRenderable: Bool?

    public init(
        index: Int,
        tokenID: Int,
        receivedNanoseconds: UInt64,
        decodedAtNanoseconds: UInt64?,
        decodedPrefix: String?,
        isSpecial: Bool?,
        isRenderable: Bool?
    ) {
        self.index = index
        self.tokenID = tokenID
        self.receivedNanoseconds = receivedNanoseconds
        self.decodedAtNanoseconds = decodedAtNanoseconds
        self.decodedPrefix = decodedPrefix
        self.isSpecial = isSpecial
        self.isRenderable = isRenderable
    }
}

public struct PowerMemorySample: Codable, Sendable, Equatable {
    public let elapsedNanoseconds: UInt64
    public let physicalFootprintBytes: UInt64

    public init(
        elapsedNanoseconds: UInt64,
        physicalFootprintBytes: UInt64
    ) {
        self.elapsedNanoseconds = elapsedNanoseconds
        self.physicalFootprintBytes = physicalFootprintBytes
    }
}

public struct PowerMemoryMeasurement: Codable, Sendable, Equatable {
    public let peakPhysicalFootprintBytes: UInt64?
    public let samples: [PowerMemorySample]

    public init(
        peakPhysicalFootprintBytes: UInt64?,
        samples: [PowerMemorySample]
    ) {
        self.peakPhysicalFootprintBytes = peakPhysicalFootprintBytes
        self.samples = samples
    }
}

public struct PowerThermalTransition: Codable, Sendable, Equatable {
    public let elapsedNanoseconds: UInt64
    public let state: PowerThermalState

    public init(
        elapsedNanoseconds: UInt64,
        state: PowerThermalState
    ) {
        self.elapsedNanoseconds = elapsedNanoseconds
        self.state = state
    }
}

public struct PowerThermalMeasurement: Codable, Sendable, Equatable {
    public let start: PowerThermalState
    public let end: PowerThermalState
    public let transitions: [PowerThermalTransition]

    public init(
        start: PowerThermalState,
        end: PowerThermalState,
        transitions: [PowerThermalTransition]
    ) {
        self.start = start
        self.end = end
        self.transitions = transitions
    }
}

public struct PowerAttemptFailure: Codable, Sendable, Equatable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public struct PowerTextAttempt: Codable, Sendable, Equatable {
    public let index: Int
    public let phase: PowerAttemptPhase
    public let outcome: PowerAttemptOutcome
    public let startedAt: String
    public let endedAt: String
    public let monotonic: PowerMonotonicMeasurement
    public let tokenCounts: PowerTokenCounts
    public let tokenEvents: [PowerTokenEvent]
    public let generatedText: String
    public let memory: PowerMemoryMeasurement
    public let thermal: PowerThermalMeasurement
    public let failure: PowerAttemptFailure?

    public init(
        index: Int,
        phase: PowerAttemptPhase,
        outcome: PowerAttemptOutcome,
        startedAt: String,
        endedAt: String,
        monotonic: PowerMonotonicMeasurement,
        tokenCounts: PowerTokenCounts,
        tokenEvents: [PowerTokenEvent],
        generatedText: String,
        memory: PowerMemoryMeasurement,
        thermal: PowerThermalMeasurement,
        failure: PowerAttemptFailure?
    ) {
        self.index = index
        self.phase = phase
        self.outcome = outcome
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.monotonic = monotonic
        self.tokenCounts = tokenCounts
        self.tokenEvents = tokenEvents
        self.generatedText = generatedText
        self.memory = memory
        self.thermal = thermal
        self.failure = failure
    }

    private enum CodingKeys: String, CodingKey {
        case index
        case phase
        case outcome
        case startedAt
        case endedAt
        case monotonic
        case tokenCounts
        case tokenEvents
        case generatedText
        case memory
        case thermal
        case failure
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(phase, forKey: .phase)
        try container.encode(outcome, forKey: .outcome)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(endedAt, forKey: .endedAt)
        try container.encode(monotonic, forKey: .monotonic)
        try container.encode(tokenCounts, forKey: .tokenCounts)
        try container.encode(tokenEvents, forKey: .tokenEvents)
        try container.encode(generatedText, forKey: .generatedText)
        try container.encode(memory, forKey: .memory)
        try container.encode(thermal, forKey: .thermal)
        try container.encode(failure, forKey: .failure)
    }
}

public struct PowerTextGenerationPayload: Codable, Sendable, Equatable {
    public let schemaVersion: String
    public let workload: PowerWorkloadIdentity
    public let measurementMode: String
    public let inferenceConfiguration: PowerInferenceConfiguration
    public let attempts: [PowerTextAttempt]

    public init(
        schemaVersion: String = PowerEvidenceConstants.textPayloadSchemaVersion,
        workload: PowerWorkloadIdentity,
        measurementMode: String,
        inferenceConfiguration: PowerInferenceConfiguration,
        attempts: [PowerTextAttempt]
    ) {
        self.schemaVersion = schemaVersion
        self.workload = workload
        self.measurementMode = measurementMode
        self.inferenceConfiguration = inferenceConfiguration
        self.attempts = attempts
    }
}

public struct PowerEvidenceEnvelope: Codable, Sendable, Equatable {
    public let schemaVersion: String
    public let resultID: UUID
    public let createdAt: String
    public let productID: String
    public let program: PowerVersionedIdentity
    public let target: PowerVersionedIdentity
    public let runnerCertificateID: String
    public let appRelease: PowerAppReleaseIdentity
    public let model: PowerModelIdentity
    public let runtime: PowerRuntimeIdentity
    public let device: PowerDeviceIdentity
    public let environment: PowerEnvironment
    public let artifacts: [PowerArtifactIdentity]
    public let payload: PowerTextGenerationPayload

    public init(
        schemaVersion: String = PowerEvidenceConstants.envelopeSchemaVersion,
        resultID: UUID,
        createdAt: String,
        productID: String = PowerEvidenceConstants.productID,
        program: PowerVersionedIdentity,
        target: PowerVersionedIdentity,
        runnerCertificateID: String,
        appRelease: PowerAppReleaseIdentity,
        model: PowerModelIdentity,
        runtime: PowerRuntimeIdentity,
        device: PowerDeviceIdentity,
        environment: PowerEnvironment,
        artifacts: [PowerArtifactIdentity],
        payload: PowerTextGenerationPayload
    ) {
        self.schemaVersion = schemaVersion
        self.resultID = resultID
        self.createdAt = createdAt
        self.productID = productID
        self.program = program
        self.target = target
        self.runnerCertificateID = runnerCertificateID
        self.appRelease = appRelease
        self.model = model
        self.runtime = runtime
        self.device = device
        self.environment = environment
        self.artifacts = artifacts
        self.payload = payload
    }
}
