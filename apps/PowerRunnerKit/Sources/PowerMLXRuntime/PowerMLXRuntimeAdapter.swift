import Foundation
import MLXLLM
import MLXLMCommon
import PowerEvidence
import PowerRunnerCore

public actor PowerMLXRuntimeAdapter: PowerRuntimeAdapter {
    private let modelContainer: ModelContainer
    public let modelDescriptor: PowerMLXModelDescriptor

    init(
        modelContainer: ModelContainer,
        modelDescriptor: PowerMLXModelDescriptor
    ) {
        self.modelContainer = modelContainer
        self.modelDescriptor = modelDescriptor
    }

    public var identity: PowerRuntimeIdentity {
        PowerMLXRuntimeIdentity.evidence
    }

    public func generate(
        request: PowerRuntimeRequest,
        onToken: @escaping @Sendable (PowerRuntimeToken) async -> Void,
        onRenderability: @escaping @Sendable (
            PowerRuntimeRenderability
        ) async -> Bool
    ) async throws -> PowerRuntimeGenerationResult {
        try PowerMLXRuntimeContract.validate(request.configuration)
        try Task.checkCancellation()

        let parameters = GenerateParameters(
            maxTokens: request.configuration.maximumOutputTokens,
            temperature: Float(request.configuration.temperature),
            topP: Float(request.configuration.topP),
            topK: request.configuration.topK,
            seed: UInt64(request.configuration.seed)
        )
        let modelContainer = self.modelContainer
        let (stream, task) = try await modelContainer.perform { context in
            let input = try await context.processor.prepare(
                input: UserInput(
                    prompt: request.prompt,
                    additionalContext: ["enable_thinking": false]
                )
            )
            return try generateTokensTask(
                input: input,
                parameters: parameters,
                context: context,
                includeStopToken: false
            )
        }

        var tokenIDs: [Int] = []
        var completionInformation: GenerateCompletionInfo?
        var shouldProbeRenderability = true
        let tokenizer = await modelContainer.tokenizer

        for await event in stream {
            try Task.checkCancellation()
            switch event {
            case .token(let tokenID):
                let index = tokenIDs.count
                tokenIDs.append(tokenID)
                await onToken(.init(index: index, tokenID: tokenID))
                if shouldProbeRenderability {
                    let decodedPrefix = tokenizer.decode(
                        tokenIds: tokenIDs,
                        skipSpecialTokens: true
                    )
                    shouldProbeRenderability = await onRenderability(
                        .init(
                            tokenIndex: index,
                            decodedPrefix: decodedPrefix,
                            isSpecial: false
                        )
                    )
                }
            case .info(let information):
                completionInformation = information
            }
        }

        await task.value
        guard let completionInformation else {
            throw PowerMLXRuntimeError.missingCompletionInformation
        }
        if completionInformation.stopReason == .cancelled {
            throw CancellationError()
        }
        guard completionInformation.generationTokenCount == tokenIDs.count
        else {
            throw PowerMLXRuntimeError.outputTokenCountMismatch(
                expected: completionInformation.generationTokenCount,
                observed: tokenIDs.count
            )
        }
        return .init(
            inputTokenCount: completionInformation.promptTokenCount,
            outputTokenCount: completionInformation.generationTokenCount,
            generatedText: tokenizer.decode(
                tokenIds: tokenIDs,
                skipSpecialTokens: true
            ),
            promptEvaluationNanoseconds: Self.nanoseconds(
                completionInformation.promptTime
            )
        )
    }

    private static func nanoseconds(_ seconds: TimeInterval) -> UInt64 {
        guard seconds.isFinite, seconds > 0 else {
            return 0
        }
        return UInt64(
            min(
                seconds * 1_000_000_000,
                Double(UInt64.max)
            ).rounded()
        )
    }
}
