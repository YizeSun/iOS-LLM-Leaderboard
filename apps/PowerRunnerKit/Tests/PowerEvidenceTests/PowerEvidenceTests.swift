import Foundation
import PowerEvidence
import XCTest

final class PowerEvidenceTests: XCTestCase {
    func testDeterministicEncodingUsesSortedKeysAndPreservesNulls() throws {
        let envelope = fixtureEnvelope()
        let first = try PowerEvidenceEncoder.encode(envelope)
        let second = try PowerEvidenceEncoder.encode(envelope)
        XCTAssertEqual(first, second)

        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: first) as? [String: Any]
        )
        XCTAssertEqual(
            root["schemaVersion"] as? String,
            PowerEvidenceConstants.envelopeSchemaVersion
        )
        let payload = try XCTUnwrap(root["payload"] as? [String: Any])
        let attempts = try XCTUnwrap(payload["attempts"] as? [[String: Any]])
        XCTAssertEqual(attempts.count, 6)
        XCTAssertTrue(attempts[0].keys.contains("failure"))
        XCTAssertTrue(attempts[0]["failure"] is NSNull)
        let monotonic = try XCTUnwrap(
            attempts[0]["monotonic"] as? [String: Any]
        )
        XCTAssertTrue(monotonic.keys.contains("firstRenderableNanoseconds"))
        XCTAssertTrue(monotonic["firstRenderableNanoseconds"] is NSNull)
    }

    func testJSONValueRejectsNonFiniteNumbers() {
        XCTAssertThrowsError(
            try PowerEvidenceEncoder.encode(
                ["bad": JSONValue.number(.infinity)]
            )
        )
    }

    private func fixtureEnvelope() -> PowerEvidenceEnvelope {
        let attempts = (0..<6).map { index in
            PowerTextAttempt(
                index: index,
                phase: index == 0 ? .warmup : .measured,
                outcome: .succeeded,
                startedAt: "2026-07-23T10:00:00.000Z",
                endedAt: "2026-07-23T10:00:01.000Z",
                monotonic: .init(
                    requestAcceptedNanoseconds: 0,
                    firstTokenNanoseconds: 10,
                    firstRenderableNanoseconds: nil,
                    completedNanoseconds: 100,
                    promptEvaluationNanoseconds: 8,
                    decodeNanoseconds: 90
                ),
                tokenCounts: .init(input: 10, output: 2),
                tokenEvents: [
                    .init(
                        index: 0,
                        tokenID: 1,
                        receivedNanoseconds: 10,
                        decodedAtNanoseconds: 11,
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
                ],
                generatedText: "ok",
                memory: .init(
                    peakPhysicalFootprintBytes: 1_000,
                    samples: [
                        .init(
                            elapsedNanoseconds: 5,
                            physicalFootprintBytes: 1_000
                        )
                    ]
                ),
                thermal: .init(
                    start: .nominal,
                    end: .nominal,
                    transitions: []
                ),
                failure: nil
            )
        }
        return PowerEvidenceEnvelope(
            resultID: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!,
            createdAt: "2026-07-23T10:00:01.000Z",
            program: .init(
                id: "text-generation-performance",
                version: "2.0.0-draft.1",
                manifestSHA256: String(repeating: "a", count: 64)
            ),
            target: .init(
                id: "apple-iphone-physical",
                version: "1.0.0-draft.1",
                manifestSHA256: String(repeating: "b", count: 64)
            ),
            runnerCertificateID: "candidate-test-certificate",
            appRelease: .init(
                version: "1.0.0",
                build: "1",
                sourceRevision: String(repeating: "c", count: 40),
                embeddedMeasurementStackSHA256:
                    String(repeating: "d", count: 64)
            ),
            model: .init(
                registryEntryID: "model",
                registryEntrySHA256: String(repeating: "e", count: 64),
                artifactID: "publisher/model",
                artifactRevision: "revision",
                parameterCount: 1,
                quantization: "4-bit",
                format: "MLX Safetensors"
            ),
            runtime: .init(
                name: "test",
                version: "1",
                resolvedRevision: "revision",
                backend: "test",
                configuration: ["seed": .integer(0)]
            ),
            device: .init(
                machineIdentifier: "iPhone17,1",
                osVersion: "iOS 26.0",
                osBuild: "23A000"
            ),
            environment: .init(
                batteryLevelAtStart: 0.8,
                batteryStateAtStart: .unplugged,
                lowPowerModeAtStart: false,
                thermalStateAtStart: .nominal,
                thermalStateAtEnd: .nominal,
                thermalAssistance: .none
            ),
            artifacts: [],
            payload: .init(
                workload: .init(
                    id: "power.text.short-interaction",
                    version: "1.0.0-draft.1",
                    sha256: String(repeating: "f", count: 64)
                ),
                measurementMode: "warm-resident-interactive-v1",
                inferenceConfiguration: .init(
                    sampling: false,
                    temperature: 0,
                    topP: 1,
                    topK: 0,
                    seed: 0,
                    maximumOutputTokens: 128,
                    reasoningMode: "disabled",
                    newContextPerAttempt: true,
                    newKVCachePerAttempt: true
                ),
                attempts: attempts
            )
        )
    }
}
