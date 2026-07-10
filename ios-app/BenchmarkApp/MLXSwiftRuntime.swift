import Foundation
import HuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

actor MLXSwiftRuntime: LanguageModelRuntime {
    enum RuntimeError: LocalizedError {
        case modelNotLoaded
        case missingCompletionInfo

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:
                "The pinned MLX model has not been loaded."
            case .missingCompletionInfo:
                "MLX generation ended without completion information."
            }
        }
    }

    nonisolated let identity =
        "MLX Swift LM 3.31.4 · mlx-community/Qwen3-0.6B-4bit@73e3e38d"

    private static let configuration = ModelConfiguration(
        id: "mlx-community/Qwen3-0.6B-4bit",
        revision: "73e3e38d981303bc594367cd910ea6eb48349da8"
    )

    private var modelContainer: ModelContainer?

    func load() async throws {
        guard modelContainer == nil else { return }
        modelContainer = try await loadModelContainer(
            from: HuggingFaceDownloader(),
            using: HuggingFaceTokenizerLoader(),
            configuration: Self.configuration,
            useLatest: false
        )
    }

    func generate(
        prompt: String,
        outputTokenLimit: Int,
        onToken: @Sendable (RuntimeToken) async -> Void
    ) async throws -> RuntimeGenerationResult {
        guard let modelContainer else {
            throw RuntimeError.modelNotLoaded
        }

        let clock = ContinuousClock()
        let parameters = GenerateParameters(
            maxTokens: outputTokenLimit,
            temperature: 0
        )

        let (stream, task, generationStart) = try await modelContainer.perform { context in
            let input = try await context.processor.prepare(
                input: UserInput(prompt: prompt)
            )
            let generationStart = clock.now
            let (stream, task) = try generateTokensTask(
                input: input,
                parameters: parameters,
                context: context,
                includeStopToken: false
            )
            return (stream, task, generationStart)
        }

        var tokenIndex = 0
        var completionInfo: GenerateCompletionInfo?

        for await event in stream {
            switch event {
            case .token(let tokenID):
                let elapsed = generationStart.duration(to: clock.now)
                await onToken(
                    RuntimeToken(
                        index: tokenIndex,
                        tokenID: tokenID,
                        elapsedNanoseconds: elapsed.nanoseconds
                    )
                )
                tokenIndex += 1
            case .info(let info):
                completionInfo = info
            }
        }

        await task.value
        guard let completionInfo else {
            throw RuntimeError.missingCompletionInfo
        }

        return RuntimeGenerationResult(
            promptTokenCount: completionInfo.promptTokenCount,
            outputTokenCount: completionInfo.generationTokenCount,
            stopReason: completionInfo.stopReason.runtimeStopReason,
            promptTimeSeconds: completionInfo.promptTime,
            generateTimeSeconds: completionInfo.generateTime
        )
    }
}

private struct HuggingFaceDownloader: Downloader {
    enum DownloadError: LocalizedError {
        case invalidRepositoryID(String)

        var errorDescription: String? {
            switch self {
            case .invalidRepositoryID(let id):
                "Invalid Hugging Face repository ID: \(id)"
            }
        }
    }

    private let client = HuggingFace.HubClient()

    func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        guard let repository = HuggingFace.Repo.ID(rawValue: id) else {
            throw DownloadError.invalidRepositoryID(id)
        }
        return try await client.downloadSnapshot(
            of: repository,
            revision: revision ?? "main",
            matching: patterns
        ) { @MainActor progress in
            progressHandler(progress)
        }
    }
}

private struct HuggingFaceTokenizerLoader: TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let tokenizer = try await Tokenizers.AutoTokenizer.from(modelFolder: directory)
        return HuggingFaceTokenizer(tokenizer)
    }
}

private struct HuggingFaceTokenizer: MLXLMCommon.Tokenizer {
    private let upstream: any Tokenizers.Tokenizer

    init(_ upstream: any Tokenizers.Tokenizer) {
        self.upstream = upstream
    }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        upstream.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        upstream.convertIdToToken(id)
    }

    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(
                messages: messages,
                tools: tools,
                additionalContext: additionalContext
            )
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}

private extension GenerateStopReason {
    var runtimeStopReason: RuntimeGenerationResult.StopReason {
        switch self {
        case .stop: .endOfSequence
        case .length: .outputTokenLimit
        case .cancelled: .cancelled
        }
    }
}

private extension Duration {
    var nanoseconds: UInt64 {
        let parts = components
        let seconds = UInt64(max(0, parts.seconds))
        let attoseconds = UInt64(max(0, parts.attoseconds))
        return seconds * 1_000_000_000 + attoseconds / 1_000_000_000
    }
}
