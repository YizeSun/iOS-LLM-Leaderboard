import Foundation
import PowerEvidence

public enum PowerAppKitFixture {
    public static let resultID = UUID(
        uuidString: "55555555-5555-4555-8555-555555555555"
    )!

    public static func envelope(
        createdAt: String = "2026-07-23T12:00:00.000Z"
    ) -> PowerEvidenceEnvelope {
        .init(
            resultID: resultID,
            createdAt: createdAt,
            program: .init(
                id: "text-generation-performance",
                version: "2.0.0-draft.1",
                manifestSHA256: String(repeating: "1", count: 64)
            ),
            target: .init(
                id: "apple-iphone-physical",
                version: "1.0.0-draft.1",
                manifestSHA256: String(repeating: "2", count: 64)
            ),
            runnerCertificateID: "power-2-test-certificate",
            appRelease: .init(
                version: "2.0.0-test",
                build: "1",
                sourceRevision: String(repeating: "a", count: 40),
                embeddedMeasurementStackSHA256: String(
                    repeating: "3",
                    count: 64
                )
            ),
            model: .init(
                registryEntryID: "model-test",
                registryEntrySHA256: String(repeating: "4", count: 64),
                artifactID: "mlx-community/model",
                artifactRevision: String(repeating: "b", count: 40),
                parameterCount: 1_000_000_000,
                quantization: "4-bit",
                format: "MLX Safetensors"
            ),
            runtime: .init(
                name: "MLX Swift LM",
                version: "3.31.4",
                resolvedRevision: String(repeating: "c", count: 40),
                backend: "mlx-metal",
                configuration: [:]
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
                    sha256: String(repeating: "5", count: 64)
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
                attempts: []
            )
        )
    }
}
