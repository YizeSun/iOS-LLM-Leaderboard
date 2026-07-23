import PowerEvidence
import PowerMLXRuntime
import XCTest

final class PowerMLXRuntimeTests: XCTestCase {
    func testRuntimeIdentityPinsEveryMeasurementDependency() {
        let identity = PowerMLXRuntimeIdentity.evidence

        XCTAssertEqual(identity.name, "MLX Swift LM")
        XCTAssertEqual(identity.version, "3.31.4")
        XCTAssertEqual(
            identity.resolvedRevision,
            "bd4b7434e6bdb588c7ef55706ff8904cb7fd4c57"
        )
        XCTAssertEqual(identity.backend, "mlx-metal")
        XCTAssertEqual(
            identity.configuration["mlxSwiftRevision"],
            .string("0bb916c67f4b9e5c682cbe02a42c701c93ab5021")
        )
        XCTAssertEqual(
            identity.configuration["tokenizerRevision"],
            .string("b38443e44d93eca770f2eb68e2a4d0fa100f9aa2")
        )
        XCTAssertEqual(
            identity.configuration["includeStopToken"],
            .boolean(false)
        )
        guard case .string(let dependencyLockSHA256) =
            identity.configuration["dependencyLockSHA256"]
        else {
            return XCTFail("dependency lock digest is missing")
        }
        XCTAssertEqual(dependencyLockSHA256.count, 64)
    }

    func testModelDescriptorRequiresExactRevision() throws {
        XCTAssertThrowsError(
            try PowerMLXModelDescriptor(
                artifactID: "mlx-community/model",
                artifactRevision: "main"
            )
        )
        let descriptor = try PowerMLXModelDescriptor(
            artifactID: "mlx-community/model",
            artifactRevision:
                "0123456789abcdef0123456789abcdef01234567"
        )
        XCTAssertEqual(descriptor.artifactID, "mlx-community/model")
    }
}
