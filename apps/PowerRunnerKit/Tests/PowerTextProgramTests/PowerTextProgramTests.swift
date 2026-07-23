import Foundation
import PowerEvidence
import PowerRunnerCore
import PowerTextProgram
import XCTest

final class PowerTextProgramTests: XCTestCase {
    func testProgramCreatesOneWarmupAndFiveMeasuredRequests() throws {
        let requests = try PowerTextProgramModule.makeRequests(
            workload: fixtureWorkload(),
            fixture: "prompt"
        )
        XCTAssertEqual(requests.count, 6)
        XCTAssertEqual(requests.first?.phase, .warmup)
        XCTAssertTrue(requests.dropFirst().allSatisfy {
            $0.phase == .measured
        })
        XCTAssertEqual(
            requests.last?.runtimeRequest.configuration.maximumOutputTokens,
            128
        )
    }

    func testProgramMapsSessionWithoutDroppingFailures() throws {
        let session = PowerRunnerSession(
            startedAt: "2026-07-23T10:00:00.000Z",
            endedAt: "2026-07-23T10:00:06.000Z",
            targetAtStart: fixtureTarget(),
            thermalStateAtEnd: .nominal,
            runtimeIdentity: .init(
                name: "fake",
                version: "1",
                resolvedRevision: "test",
                backend: "fake",
                configuration: [:]
            ),
            attempts: (0..<6).map { index in
                let succeeds = index != 2
                return PowerRunnerAttemptRecord(
                    index: index,
                    phase: index == 0 ? .warmup : .measured,
                    outcome: succeeds ? .succeeded : .oom,
                    startedAt: "2026-07-23T10:00:00.000Z",
                    endedAt: "2026-07-23T10:00:01.000Z",
                    requestAcceptedNanoseconds: 0,
                    firstTokenNanoseconds: succeeds ? 10 : nil,
                    firstRenderableNanoseconds: succeeds ? 20 : nil,
                    completedNanoseconds: succeeds ? 100 : nil,
                    promptEvaluationNanoseconds: succeeds ? 8 : nil,
                    decodeNanoseconds: succeeds ? 90 : nil,
                    inputTokenCount: succeeds ? 4 : 0,
                    outputTokenCount: succeeds ? 2 : 0,
                    tokenEvents: succeeds
                        ? [
                            .init(
                                index: 0,
                                tokenID: 1,
                                receivedNanoseconds: 10,
                                decodedAtNanoseconds: 20,
                                decodedPrefix: "ok",
                                isSpecial: false,
                                isRenderable: true
                            ),
                            .init(
                                index: 1,
                                tokenID: 2,
                                receivedNanoseconds: 100,
                                decodedAtNanoseconds: nil,
                                decodedPrefix: nil,
                                isSpecial: nil,
                                isRenderable: nil
                            ),
                        ]
                        : [],
                    generatedText: succeeds ? "ok" : "",
                    peakPhysicalFootprintBytes: 1_000,
                    memorySamples: [
                        .init(
                            elapsedNanoseconds: 5,
                            physicalFootprintBytes: 1_000
                        )
                    ],
                    thermalStateAtStart: .nominal,
                    thermalStateAtEnd: .nominal,
                    thermalTransitions: [],
                    failure: succeeds
                        ? nil
                        : .init(code: "oom", message: "out of memory")
                )
            }
        )

        let payload = try PowerTextProgramModule.makePayload(
            workload: fixtureWorkload(),
            workloadSHA256: String(repeating: "a", count: 64),
            session: session
        )
        XCTAssertEqual(payload.attempts.count, 6)
        XCTAssertEqual(payload.attempts[2].outcome, .oom)
        XCTAssertEqual(payload.attempts[2].failure?.code, "oom")
        XCTAssertEqual(
            payload.measurementMode,
            "warm-resident-interactive-v1"
        )
    }

    func testUnsupportedMeasurementModeFailsClosed() {
        var workload = fixtureWorkloadValues()
        workload["measurementMode"] = "unregistered-mode"
        XCTAssertThrowsError(
            try PowerTextWorkload.decode(
                JSONSerialization.data(withJSONObject: workload)
            )
        ) { error in
            XCTAssertEqual(
                error as? PowerTextProgramError,
                .unsupportedMeasurementMode("unregistered-mode")
            )
        }
    }

    private func fixtureWorkload() -> PowerTextWorkload {
        try! PowerTextWorkload.decode(
            JSONSerialization.data(withJSONObject: fixtureWorkloadValues())
        )
    }

    private func fixtureWorkloadValues() -> [String: Any] {
        [
            "schemaVersion": "power-workload-1.0.0-draft.1",
            "programID": "text-generation-performance",
            "programVersion": "2.0.0-draft.1",
            "workloadID": "power.text.short-interaction",
            "workloadVersion": "1.0.0-draft.1",
            "status": "migration-draft",
            "title": "Short Interaction",
            "category": "interactive",
            "fixture": [
                "path": "fixture.txt",
                "sha256": String(repeating: "a", count: 64),
            ],
            "measurementMode": "warm-resident-interactive-v1",
            "generation": [
                "sampling": false,
                "temperature": 0,
                "topP": 1,
                "topK": 0,
                "seed": 0,
                "maximumOutputTokens": 128,
                "reasoningMode": "disabled",
                "newContextPerAttempt": true,
                "newKVCachePerAttempt": true,
            ],
            "procedure": [
                "warmupAttempts": 1,
                "measuredAttempts": 5,
                "restIntervalSeconds": 0,
            ],
            "primaryMetric": "first_renderable_ms",
            "metrics": ["first_renderable_ms"],
        ]
    }

    private func fixtureTarget() -> PowerTargetSnapshot {
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
            thermalState: .nominal
        )
    }
}
