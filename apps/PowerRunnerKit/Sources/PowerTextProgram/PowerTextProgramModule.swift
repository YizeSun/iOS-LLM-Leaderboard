import Foundation
import PowerEvidence
import PowerRunnerCore

public enum PowerTextProgramModule {
    public static let programID = "text-generation-performance"
    public static let programVersion = "2.0.0-draft.2"

    public static func makeRequests(
        workload: PowerTextWorkload,
        fixture: String
    ) throws -> [PowerRunnerAttemptRequest] {
        try workload.validate()
        guard !fixture.isEmpty else {
            throw PowerTextProgramError.fixtureIsEmpty
        }
        let count =
            workload.procedure.warmupAttempts
            + workload.procedure.measuredAttempts
        return (0..<count).map { index in
            PowerRunnerAttemptRequest(
                index: index,
                phase: index == 0 ? .warmup : .measured,
                runtimeRequest: .init(
                    prompt: fixture,
                    configuration: workload.generation
                )
            )
        }
    }

    public static func makePayload(
        workload: PowerTextWorkload,
        workloadSHA256: String,
        session: PowerRunnerSession
    ) throws -> PowerTextGenerationPayload {
        try workload.validate()
        guard session.attempts.count == 6 else {
            throw PowerTextProgramError.attemptCountMismatch
        }

        let attempts = try session.attempts.enumerated().map {
            position,
            source in
            let expectedPhase: PowerAttemptPhase =
                position == 0 ? .warmup : .measured
            guard source.index == position, source.phase == expectedPhase else {
                throw PowerTextProgramError.attemptSequenceMismatch(
                    index: position
                )
            }
            if source.outcome == .succeeded, source.failure != nil {
                throw PowerTextProgramError.succeededAttemptHasFailure(
                    index: position
                )
            }
            if source.outcome != .succeeded, source.failure == nil {
                throw PowerTextProgramError
                    .unsuccessfulAttemptMissingFailure(index: position)
            }
            return PowerTextAttempt(
                index: source.index,
                phase: source.phase,
                outcome: source.outcome,
                startedAt: source.startedAt,
                endedAt: source.endedAt,
                monotonic: .init(
                    requestAcceptedNanoseconds:
                        source.requestAcceptedNanoseconds,
                    firstTokenNanoseconds:
                        source.firstTokenNanoseconds,
                    firstRenderableNanoseconds:
                        source.firstRenderableNanoseconds,
                    completedNanoseconds:
                        source.completedNanoseconds,
                    promptEvaluationNanoseconds:
                        source.promptEvaluationNanoseconds,
                    decodeNanoseconds: source.decodeNanoseconds
                ),
                tokenCounts: .init(
                    input: source.inputTokenCount,
                    output: source.outputTokenCount
                ),
                tokenEvents: source.tokenEvents,
                generatedText: source.generatedText,
                memory: .init(
                    peakPhysicalFootprintBytes:
                        source.peakPhysicalFootprintBytes,
                    samples: source.memorySamples
                ),
                thermal: .init(
                    start: source.thermalStateAtStart,
                    end: source.thermalStateAtEnd,
                    transitions: source.thermalTransitions
                ),
                failure: source.failure
            )
        }

        return PowerTextGenerationPayload(
            workload: .init(
                id: workload.workloadID,
                version: workload.workloadVersion,
                sha256: workloadSHA256
            ),
            measurementMode: workload.measurementMode,
            inferenceConfiguration: workload.generation,
            attempts: attempts
        )
    }
}
