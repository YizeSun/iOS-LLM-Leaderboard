import Foundation
import PowerEvidence
import PowerRunnerCore

public struct PowerTextWorkload: Codable, Sendable, Equatable {
    public struct Fixture: Codable, Sendable, Equatable {
        public let path: String
        public let sha256: String

        public init(path: String, sha256: String) {
            self.path = path
            self.sha256 = sha256
        }
    }

    public struct Procedure: Codable, Sendable, Equatable {
        public let warmupAttempts: Int
        public let measuredAttempts: Int
        public let restIntervalSeconds: Double

        public init(
            warmupAttempts: Int,
            measuredAttempts: Int,
            restIntervalSeconds: Double
        ) {
            self.warmupAttempts = warmupAttempts
            self.measuredAttempts = measuredAttempts
            self.restIntervalSeconds = restIntervalSeconds
        }
    }

    public let schemaVersion: String
    public let programID: String
    public let programVersion: String
    public let workloadID: String
    public let workloadVersion: String
    public let status: String
    public let title: String
    public let category: String
    public let fixture: Fixture
    public let measurementMode: String
    public let generation: PowerInferenceConfiguration
    public let procedure: Procedure
    public let primaryMetric: String
    public let metrics: [String]

    public init(
        schemaVersion: String,
        programID: String,
        programVersion: String,
        workloadID: String,
        workloadVersion: String,
        status: String,
        title: String,
        category: String,
        fixture: Fixture,
        measurementMode: String,
        generation: PowerInferenceConfiguration,
        procedure: Procedure,
        primaryMetric: String,
        metrics: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.programID = programID
        self.programVersion = programVersion
        self.workloadID = workloadID
        self.workloadVersion = workloadVersion
        self.status = status
        self.title = title
        self.category = category
        self.fixture = fixture
        self.measurementMode = measurementMode
        self.generation = generation
        self.procedure = procedure
        self.primaryMetric = primaryMetric
        self.metrics = metrics
    }

    public static func decode(_ data: Data) throws -> PowerTextWorkload {
        let value = try JSONDecoder().decode(Self.self, from: data)
        try value.validate()
        return value
    }

    public func validate() throws {
        guard schemaVersion == "power-workload-1.0.0-draft.1" else {
            throw PowerTextProgramError.unsupportedWorkloadSchema(
                schemaVersion
            )
        }
        guard programID == PowerTextProgramModule.programID,
              programVersion == PowerTextProgramModule.programVersion
        else {
            throw PowerTextProgramError.programIdentityMismatch
        }
        guard Self.allowedWorkloads.contains(workloadID),
              workloadVersion == "1.0.0-draft.1"
        else {
            throw PowerTextProgramError.unsupportedWorkload(workloadID)
        }
        guard Self.allowedMeasurementModes.contains(measurementMode) else {
            throw PowerTextProgramError.unsupportedMeasurementMode(
                measurementMode
            )
        }
        guard procedure.warmupAttempts == 1,
              procedure.measuredAttempts == 5,
              procedure.restIntervalSeconds == 0
        else {
            throw PowerTextProgramError.invalidAttemptProcedure
        }
        guard generation.maximumOutputTokens > 0,
              generation.newContextPerAttempt,
              generation.newKVCachePerAttempt
        else {
            throw PowerTextProgramError.invalidInferenceConfiguration
        }
    }

    private static let allowedWorkloads: Set<String> = [
        "power.text.short-interaction",
        "power.text.sustained-generation",
    ]

    private static let allowedMeasurementModes: Set<String> = [
        "warm-resident-interactive-v1",
        "warm-resident-sustained-v1",
    ]
}
public enum PowerTextProgramError: Error, Sendable, Equatable {
    case unsupportedWorkloadSchema(String)
    case programIdentityMismatch
    case unsupportedWorkload(String)
    case unsupportedMeasurementMode(String)
    case invalidAttemptProcedure
    case invalidInferenceConfiguration
    case fixtureIsEmpty
    case attemptCountMismatch
    case attemptSequenceMismatch(index: Int)
    case succeededAttemptHasFailure(index: Int)
    case unsuccessfulAttemptMissingFailure(index: Int)
}
