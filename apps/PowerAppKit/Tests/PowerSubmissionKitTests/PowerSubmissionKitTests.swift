import CryptoKit
import Foundation
import PowerAppKitTestSupport
import PowerEvidence
import PowerSubmissionKit
import XCTest

final class PowerSubmissionKitTests: XCTestCase {
    func testPackagePreservesEvidenceAndCreatesCurrentDeclaration()
        throws
    {
        let resultBytes = try PowerEvidenceEncoder.encode(
            PowerAppKitFixture.envelope()
        )
        let submissionID = UUID(
            uuidString: "44444444-4444-4444-8444-444444444444"
        )!
        let package = try PowerSubmissionPackage(
            encodedEvidence: resultBytes,
            githubLogin: "Power-Fixture-User",
            conflictOfInterest: .none,
            disclosure: nil,
            environmentNotes: "  tabletop  ",
            submissionID: submissionID,
            createdAt: Date(timeIntervalSince1970: 1_774_000_000)
        )
        let declaration = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: package.submissionData
            ) as? [String: Any]
        )
        let source = try XCTUnwrap(
            declaration["sourceResult"] as? [String: Any]
        )
        let contributor = try XCTUnwrap(
            declaration["contributor"] as? [String: Any]
        )

        XCTAssertEqual(package.resultData, resultBytes)
        XCTAssertEqual(
            package.repositoryDirectory,
            "submissions/power/text-generation-performance/2.0.0/draft/"
                + submissionID.uuidString.lowercased()
        )
        XCTAssertEqual(
            declaration["schemaVersion"] as? String,
            "power-submission-1.0.0-draft.1"
        )
        XCTAssertEqual(
            source["sha256"] as? String,
            SHA256.hash(data: resultBytes).map {
                String(format: "%02x", $0)
            }.joined()
        )
        XCTAssertEqual(
            contributor["githubLogin"] as? String,
            "Power-Fixture-User"
        )
        XCTAssertEqual(
            declaration["environmentNotes"] as? String,
            "tabletop"
        )
    }

    func testDisclosedConflictRequiresText() throws {
        let resultBytes = try PowerEvidenceEncoder.encode(
            PowerAppKitFixture.envelope()
        )
        XCTAssertThrowsError(
            try PowerSubmissionPackage(
                encodedEvidence: resultBytes,
                githubLogin: "fixture",
                conflictOfInterest: .disclosed,
                disclosure: " ",
                environmentNotes: nil
            )
        )
    }
}
