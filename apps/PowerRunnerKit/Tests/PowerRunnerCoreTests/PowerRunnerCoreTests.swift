import Foundation
import PowerEvidence
import PowerRunnerCore
import XCTest

final class PowerRunnerCoreTests: XCTestCase {
    func testRunnerPreservesEveryTerminalOutcomeInOrder() async throws {
        let runtime = FakeRuntime(
            outcomes: [
                .success,
                .failure,
                .outOfMemory,
                .cancelled,
                .success,
                .failure,
            ]
        )
        let sink = RecordingSink()
        let runner = PowerRunner(
            runtime: runtime,
            target: FakeTarget(),
            clock: IncrementingClock(),
            checkpointSink: sink,
            memorySamplingInterval: .milliseconds(1),
            timestamp: { "2026-07-23T10:00:00.000Z" }
        )

        let session = try await runner.run(requests: fixtureRequests())

        XCTAssertEqual(session.attempts.count, 6)
        XCTAssertEqual(
            session.attempts.map(\.outcome),
            [.succeeded, .failed, .oom, .cancelled, .succeeded, .failed]
        )
        XCTAssertEqual(session.attempts.map(\.index), Array(0..<6))
        XCTAssertEqual(session.attempts[0].phase, .warmup)
        XCTAssertTrue(session.attempts.dropFirst().allSatisfy {
            $0.phase == .measured
        })
        XCTAssertNil(session.attempts[0].failure)
        XCTAssertNotNil(session.attempts[1].failure)
        XCTAssertNotNil(session.attempts[2].failure)
        XCTAssertNotNil(session.attempts[3].failure)
        XCTAssertEqual(session.attempts[0].requestAcceptedNanoseconds, 0)
        XCTAssertNotNil(session.attempts[0].firstTokenNanoseconds)
        XCTAssertNotNil(session.attempts[0].firstRenderableNanoseconds)
        XCTAssertEqual(session.attempts[0].tokenEvents.count, 3)
        XCTAssertTrue(
            session.attempts[0].tokenEvents[1].isRenderable == true
        )
        XCTAssertNil(session.attempts[0].tokenEvents[2].decodedAtNanoseconds)
        XCTAssertNotNil(
            session.attempts[0].peakPhysicalFootprintBytes
        )
        XCTAssertFalse(session.attempts[0].memorySamples.isEmpty)

        let started = await sink.started
        let recorded = await sink.recorded
        XCTAssertEqual(started, Array(0..<6))
        XCTAssertEqual(recorded.map(\.index), Array(0..<6))
    }

    func testCriticalThermalStateProducesSixRetainedNotRunRecords()
        async throws
    {
        let runner = PowerRunner(
            runtime: FakeRuntime(outcomes: Array(repeating: .success, count: 6)),
            target: FakeTarget(thermalState: .critical),
            clock: IncrementingClock(),
            timestamp: { "2026-07-23T10:00:00.000Z" }
        )
        let session = try await runner.run(requests: fixtureRequests())
        XCTAssertEqual(session.attempts.count, 6)
        XCTAssertTrue(session.attempts.allSatisfy {
            $0.outcome == .notRun
                && $0.failure?.code
                    == "thermal_state_critical_before_attempt"
        })
    }

    private func fixtureRequests() -> [PowerRunnerAttemptRequest] {
        let configuration = PowerInferenceConfiguration(
            sampling: false,
            temperature: 0,
            topP: 1,
            topK: 0,
            seed: 0,
            maximumOutputTokens: 128,
            reasoningMode: "disabled",
            newContextPerAttempt: true,
            newKVCachePerAttempt: true
        )
        return (0..<6).map { index in
            PowerRunnerAttemptRequest(
                index: index,
                phase: index == 0 ? .warmup : .measured,
                runtimeRequest: .init(
                    prompt: "test",
                    configuration: configuration
                )
            )
        }
    }
}

private final class IncrementingClock: PowerMonotonicClock, @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 0

    func nowNanoseconds() -> UInt64 {
        lock.withLock {
            value += 10
            return value
        }
    }
}

private actor FakeTarget: PowerTargetAdapter {
    let thermalState: PowerThermalState
    private var memory: UInt64 = 1_000

    init(thermalState: PowerThermalState = .nominal) {
        self.thermalState = thermalState
    }

    func captureStart() async throws -> PowerTargetSnapshot {
        PowerTargetSnapshot(
            isPhysicalDevice: true,
            device: .init(
                machineIdentifier: "iPhone17,1",
                osVersion: "iOS 26.0",
                osBuild: "23A000"
            ),
            batteryLevel: 0.8,
            batteryState: .unplugged,
            lowPowerModeEnabled: false,
            thermalState: thermalState
        )
    }

    func currentThermalState() async -> PowerThermalState {
        thermalState
    }

    func currentPhysicalFootprintBytes() async -> UInt64? {
        memory += 1
        return memory
    }
}

private actor FakeRuntime: PowerRuntimeAdapter {
    enum Outcome {
        case success
        case failure
        case outOfMemory
        case cancelled
    }

    let identity = PowerRuntimeIdentity(
        name: "fake",
        version: "1",
        resolvedRevision: "test",
        backend: "fake",
        configuration: [:]
    )

    private let outcomes: [Outcome]
    private var index = 0

    init(outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    func generate(
        request: PowerRuntimeRequest,
        onToken: @escaping @Sendable (PowerRuntimeToken) async -> Void,
        onRenderability: @escaping @Sendable (
            PowerRuntimeRenderability
        ) async -> Bool
    ) async throws -> PowerRuntimeGenerationResult {
        let outcome = outcomes[index]
        index += 1
        switch outcome {
        case .success:
            await onToken(
                .init(index: 0, tokenID: 1)
            )
            _ = await onRenderability(
                .init(tokenIndex: 0, decodedPrefix: " ", isSpecial: false)
            )
            await onToken(
                .init(index: 1, tokenID: 2)
            )
            _ = await onRenderability(
                .init(tokenIndex: 1, decodedPrefix: "ok", isSpecial: false)
            )
            await onToken(
                .init(index: 2, tokenID: 3)
            )
            _ = await onRenderability(
                .init(
                    tokenIndex: 2,
                    decodedPrefix: "ignored",
                    isSpecial: false
                )
            )
            return .init(
                inputTokenCount: 4,
                outputTokenCount: 3,
                generatedText: "ok ignored",
                promptEvaluationNanoseconds: 4
            )
        case .failure:
            throw FakeFailure.runtime
        case .outOfMemory:
            throw FakeFailure.memory
        case .cancelled:
            throw CancellationError()
        }
    }
}

private enum FakeFailure: Error, PowerRuntimeFailureClassifyingError {
    case runtime
    case memory

    var powerRuntimeFailureKind: PowerRuntimeFailureKind {
        switch self {
        case .runtime:
            .failed(code: "fake_runtime_failure")
        case .memory:
            .outOfMemory(code: "fake_runtime_oom")
        }
    }
}

private actor RecordingSink: PowerAttemptCheckpointSink {
    private(set) var started: [Int] = []
    private(set) var recorded: [PowerRunnerAttemptRecord] = []

    func markAttemptStarted(
        index: Int,
        phase: PowerAttemptPhase,
        startedAt: String,
        thermalStateAtStart: PowerThermalState
    ) async throws {
        started.append(index)
    }

    func record(_ attempt: PowerRunnerAttemptRecord) async throws {
        recorded.append(attempt)
    }
}
