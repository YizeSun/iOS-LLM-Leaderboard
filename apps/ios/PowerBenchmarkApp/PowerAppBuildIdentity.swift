import Foundation
import PowerEvidence

enum PowerAppBuildKind: String {
    case developer
    case certification
    case official
    case invalid

    var displayName: String {
        switch self {
        case .developer:
            "Developer"
        case .certification:
            "Certification"
        case .official:
            "Official"
        case .invalid:
            "Invalid"
        }
    }
}

enum PowerAppBuildIdentity {
    #if POWER_CERTIFICATION
    private static let compiledKind: PowerAppBuildKind = .certification
    #elseif POWER_OFFICIAL
    private static let compiledKind: PowerAppBuildKind = .official
    #else
    private static let compiledKind: PowerAppBuildKind = .developer
    #endif

    static var kind: PowerAppBuildKind {
        guard declaredKind == compiledKind else { return .invalid }
        return compiledKind
    }

    static var isCertificationBuild: Bool {
        kind == .certification
    }

    static var isOfficialBuild: Bool {
        kind == .official
    }

    static var isDeveloperBuild: Bool {
        kind == .developer
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? ""
    }

    static var sourceRevision: String {
        Bundle.main.object(
            forInfoDictionaryKey: "PowerSourceRevision"
        ) as? String ?? ""
    }

    static var appRelease: PowerAppReleaseIdentity? {
        switch kind {
        case .certification where certificationMeasurementAvailable:
            return makeAppRelease(version: "2.0.0-certification")
        case .official where officialReleaseAvailable:
            return makeAppRelease(version: marketingVersion)
        case .developer, .certification, .official, .invalid:
            return nil
        }
    }

    static var measurementAvailable: Bool {
        certificationMeasurementAvailable || officialReleaseAvailable
    }

    static var certificationMeasurementAvailable: Bool {
        isCertificationBuild
            && isValidSourceRevision(sourceRevision)
            && !Power2CandidateIdentity.publicIntakeOpen
            && !Power2CandidateIdentity.appReleaseAvailable
    }

    static var officialReleaseAvailable: Bool {
        isOfficialBuild
            && isValidSourceRevision(sourceRevision)
            && Power2CandidateIdentity.publicIntakeOpen
            && Power2CandidateIdentity.appReleaseAvailable
    }

    private static var marketingVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "unknown"
    }

    private static var buildVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "unknown"
    }

    private static func makeAppRelease(
        version: String
    ) -> PowerAppReleaseIdentity {
        .init(
            version: version,
            build: buildVersion,
            sourceRevision: sourceRevision,
            embeddedMeasurementStackSHA256:
                Power2CandidateIdentity.measurementStackSHA256
        )
    }

    private static var declaredKind: PowerAppBuildKind {
        guard
            let value = Bundle.main.object(
                forInfoDictionaryKey: "PowerBuildKind"
            ) as? String,
            let kind = PowerAppBuildKind(rawValue: value)
        else {
            return .invalid
        }
        return kind
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
