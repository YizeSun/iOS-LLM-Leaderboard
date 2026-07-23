import Foundation
import HuggingFace
import MLXLLM
import MLXLMCommon

public struct PowerMLXModelDescriptor: Sendable, Equatable {
    public let artifactID: String
    public let artifactRevision: String
    public let extraEndOfSequenceTokens: Set<String>

    public init(
        artifactID: String,
        artifactRevision: String,
        extraEndOfSequenceTokens: Set<String> = []
    ) throws {
        guard
            artifactID.split(separator: "/").count == 2,
            artifactRevision.count == 40,
            artifactRevision.allSatisfy(\.isHexDigit)
        else {
            throw PowerMLXRuntimeError.invalidArtifactIdentity
        }
        self.artifactID = artifactID
        self.artifactRevision = artifactRevision
        self.extraEndOfSequenceTokens = extraEndOfSequenceTokens
    }
}

public enum PowerMLXModelLoader {
    public static func load(
        descriptor: PowerMLXModelDescriptor,
        localFilesOnly: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
    ) async throws -> PowerMLXRuntimeAdapter {
        let configuration = ModelConfiguration(
            id: descriptor.artifactID,
            revision: descriptor.artifactRevision,
            extraEOSTokens: descriptor.extraEndOfSequenceTokens
        )
        let container = try await loadModelContainer(
            from: PowerHuggingFaceDownloader(
                localFilesOnly: localFilesOnly
            ),
            using: PowerMLXTokenizerLoader(),
            configuration: configuration,
            useLatest: false,
            progressHandler: progressHandler
        )
        return PowerMLXRuntimeAdapter(
            modelContainer: container,
            modelDescriptor: descriptor
        )
    }
}

private struct PowerHuggingFaceDownloader: Downloader {
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
    let localFilesOnly: Bool

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
            matching: patterns,
            localFilesOnly: localFilesOnly
        ) { @MainActor progress in
            progressHandler(progress)
        }
    }
}
