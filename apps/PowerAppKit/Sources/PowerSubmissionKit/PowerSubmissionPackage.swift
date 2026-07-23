import CryptoKit
import Foundation
import PowerEvidence

public enum PowerSubmissionConflict:
    String, Codable, Sendable, CaseIterable, Hashable
{
    case none
    case disclosed
}

public struct PowerSubmissionRoute: Sendable, Equatable {
    public let repositoryDirectoryPrefix: String

    public init(
        repositoryDirectoryPrefix: String =
            "submissions/power/text-generation-performance/2.0.0/draft"
    ) {
        self.repositoryDirectoryPrefix = repositoryDirectoryPrefix
    }
}

public struct PowerSubmissionPackage: Sendable, Equatable {
    public let submissionID: UUID
    public let submissionData: Data
    public let resultData: Data
    public let repositoryDirectory: String

    public init(
        encodedEvidence resultData: Data,
        githubLogin: String,
        conflictOfInterest: PowerSubmissionConflict,
        disclosure: String?,
        environmentNotes: String?,
        route: PowerSubmissionRoute = .init(),
        submissionID: UUID = UUID(),
        createdAt: Date = Date()
    ) throws {
        let evidence: PowerEvidenceEnvelope
        do {
            evidence = try JSONDecoder().decode(
                PowerEvidenceEnvelope.self,
                from: resultData
            )
        } catch {
            throw PackageError.invalidEvidence
        }
        guard evidence.schemaVersion
                == PowerEvidenceConstants.envelopeSchemaVersion,
              evidence.productID == PowerEvidenceConstants.productID
        else {
            throw PackageError.invalidEvidence
        }
        let login = githubLogin.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard Self.isValidGitHubLogin(login) else {
            throw PackageError.invalidGitHubLogin
        }
        let normalizedDisclosure = disclosure?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if conflictOfInterest == .disclosed,
           normalizedDisclosure?.isEmpty != false {
            throw PackageError.missingDisclosure
        }
        let notes = environmentNotes?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let digest = SHA256.hash(data: resultData).map {
            String(format: "%02x", $0)
        }.joined()
        let declaration = SubmissionDeclaration(
            submissionID: submissionID,
            createdAt: PowerEvidenceTimestamp.string(from: createdAt),
            contributor: .init(
                githubLogin: login,
                conflictOfInterest: conflictOfInterest,
                disclosure: conflictOfInterest == .disclosed
                    ? normalizedDisclosure
                    : nil
            ),
            sourceResult: .init(sha256: digest),
            environmentNotes: notes?.isEmpty == false ? notes : nil
        )

        self.submissionID = submissionID
        self.submissionData = try PowerEvidenceEncoder.encode(declaration)
        self.resultData = resultData
        self.repositoryDirectory =
            "\(route.repositoryDirectoryPrefix)/"
            + submissionID.uuidString.lowercased()
    }

    public enum PackageError: Error, LocalizedError {
        case invalidEvidence
        case invalidGitHubLogin
        case missingDisclosure

        public var errorDescription: String? {
            switch self {
            case .invalidEvidence:
                "The selected bytes are not a Power 2 evidence envelope."
            case .invalidGitHubLogin:
                "The authenticated GitHub login is invalid."
            case .missingDisclosure:
                "A disclosed conflict of interest requires an explanation."
            }
        }
    }

    private struct SubmissionDeclaration: Encodable {
        let schemaVersion = "power-submission-1.0.0-draft.1"
        let submissionID: UUID
        let createdAt: String
        let contributor: Contributor
        let sourceResult: SourceResult
        let declarations = Declarations()
        let environmentNotes: String?

        struct Contributor: Encodable {
            let githubLogin: String
            let conflictOfInterest: PowerSubmissionConflict
            let disclosure: String?
        }

        struct SourceResult: Encodable {
            let path = "result.json"
            let sha256: String
            let schemaVersion =
                PowerEvidenceConstants.envelopeSchemaVersion
        }

        struct Declarations: Encodable {
            let physicalDevice = true
            let publicMetadataReviewed = true
            let rawEvidenceUnmodified = true
            let containsNoPersonalData = true
            let licenseAccepted = "CC-BY-4.0"
            let rankingNotGuaranteed = true
        }
    }

    private static func isValidGitHubLogin(_ value: String) -> Bool {
        guard value.count <= 39 else { return false }
        return value.range(
            of: #"^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$"#,
            options: .regularExpression
        ) != nil
    }
}
