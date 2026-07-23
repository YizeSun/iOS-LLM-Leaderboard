import CryptoKit
import Foundation
import PowerEvidence

public struct StoredPowerResult: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let createdAt: String
    public let programID: String
    public let workloadID: String
    public let modelArtifactID: String
    public let appRelease: PowerAppReleaseIdentity
    public let sha256: String
    public let byteCount: Int
    public let fileURL: URL
}

public actor PowerResultsStore {
    public enum StoreError: Error, LocalizedError {
        case resultIDCollision(UUID)
        case symbolicLinkNotAllowed(URL)
        case invalidEvidence(URL)

        public var errorDescription: String? {
            switch self {
            case .resultIDCollision(let id):
                "A different result already uses ID \(id.uuidString)."
            case .symbolicLinkNotAllowed(let url):
                "Symbolic links are not allowed in the result store: \(url.path)"
            case .invalidEvidence(let url):
                "The saved file is not a Power 2 evidence envelope: \(url.path)"
            }
        }
    }

    private let directory: URL
    private let fileManager: FileManager
    private let decoder = JSONDecoder()

    public init(
        directory: URL,
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.fileManager = fileManager
    }

    @discardableResult
    public func save(
        envelope: PowerEvidenceEnvelope
    ) throws -> StoredPowerResult {
        let bytes = try PowerEvidenceEncoder.encode(envelope)
        return try save(encodedEvidence: bytes)
    }

    /// Saves source evidence without ever re-encoding caller-provided bytes.
    @discardableResult
    public func save(encodedEvidence bytes: Data) throws -> StoredPowerResult {
        let envelope: PowerEvidenceEnvelope
        do {
            envelope = try decoder.decode(
                PowerEvidenceEnvelope.self,
                from: bytes
            )
        } catch {
            throw StoreError.invalidEvidence(directory)
        }
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let destination = fileURL(for: envelope.resultID)
        if fileManager.fileExists(atPath: destination.path) {
            try rejectSymbolicLink(destination)
            let existing = try Data(contentsOf: destination)
            guard existing == bytes else {
                throw StoreError.resultIDCollision(envelope.resultID)
            }
            return record(
                envelope: envelope,
                bytes: existing,
                url: destination
            )
        }
        try bytes.write(to: destination, options: [.atomic])
        return record(
            envelope: envelope,
            bytes: bytes,
            url: destination
        )
    }

    public func list() throws -> [StoredPowerResult] {
        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ],
            options: [.skipsHiddenFiles]
        )
        return try urls
            .filter { $0.pathExtension == "json" }
            .map { url in
                try rejectSymbolicLink(url)
                let values = try url.resourceValues(
                    forKeys: [.isRegularFileKey]
                )
                guard values.isRegularFile == true else {
                    throw StoreError.invalidEvidence(url)
                }
                let bytes = try Data(contentsOf: url)
                guard
                    let envelope = try? decoder.decode(
                        PowerEvidenceEnvelope.self,
                        from: bytes
                    ),
                    url.deletingPathExtension().lastPathComponent
                        == envelope.resultID.uuidString.lowercased()
                else {
                    throw StoreError.invalidEvidence(url)
                }
                return record(
                    envelope: envelope,
                    bytes: bytes,
                    url: url
                )
            }
            .sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.createdAt > $1.createdAt
            }
    }

    public func encodedEvidence(for resultID: UUID) throws -> Data {
        let url = fileURL(for: resultID)
        try rejectSymbolicLink(url)
        let bytes = try Data(contentsOf: url)
        guard
            let envelope = try? decoder.decode(
                PowerEvidenceEnvelope.self,
                from: bytes
            ),
            envelope.resultID == resultID
        else {
            throw StoreError.invalidEvidence(url)
        }
        return bytes
    }

    private func fileURL(for resultID: UUID) -> URL {
        directory.appendingPathComponent(
            "\(resultID.uuidString.lowercased()).json",
            isDirectory: false
        )
    }

    private func rejectSymbolicLink(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values.isSymbolicLink == true {
            throw StoreError.symbolicLinkNotAllowed(url)
        }
    }

    private func record(
        envelope: PowerEvidenceEnvelope,
        bytes: Data,
        url: URL
    ) -> StoredPowerResult {
        let canonicalURL = url.standardizedFileURL
            .resolvingSymlinksInPath()
        return StoredPowerResult(
            id: envelope.resultID,
            createdAt: envelope.createdAt,
            programID: envelope.program.id,
            workloadID: envelope.payload.workload.id,
            modelArtifactID: envelope.model.artifactID,
            appRelease: envelope.appRelease,
            sha256: SHA256.hash(data: bytes).map {
                String(format: "%02x", $0)
            }.joined(),
            byteCount: bytes.count,
            fileURL: canonicalURL
        )
    }
}
