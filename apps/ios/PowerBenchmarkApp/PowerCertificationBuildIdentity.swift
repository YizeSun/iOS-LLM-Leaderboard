import Foundation
import PowerEvidence

enum PowerCertificationBuildIdentity {
    #if POWER_CERTIFICATION
    static let isCertificationBuild = true
    #else
    static let isCertificationBuild = false
    #endif

    static var sourceRevision: String {
        Bundle.main.object(
            forInfoDictionaryKey: "PowerSourceRevision"
        ) as? String ?? ""
    }

    static var appRelease: PowerAppReleaseIdentity? {
        guard isAvailable else { return nil }
        let build =
            Bundle.main.object(
                forInfoDictionaryKey: "CFBundleVersion"
            ) as? String ?? "unknown"
        return .init(
            version: "2.0.0-certification",
            build: build,
            sourceRevision: sourceRevision,
            embeddedMeasurementStackSHA256:
                Power2CandidateIdentity.measurementStackSHA256
        )
    }

    static var isAvailable: Bool {
        isCertificationBuild
            && isValidSourceRevision(sourceRevision)
            && !Power2CandidateIdentity.publicIntakeOpen
            && !Power2CandidateIdentity.appReleaseAvailable
    }

    private static func isValidSourceRevision(_ value: String) -> Bool {
        guard value.count == 40 || value.count == 64 else { return false }
        guard value != String(repeating: "0", count: value.count) else {
            return false
        }
        return value.allSatisfy {
            $0.isNumber || ("a"..."f").contains(String($0))
        }
    }
}
