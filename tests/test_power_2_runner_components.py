from __future__ import annotations

import hashlib
import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "apps/PowerRunnerKit/component-manifest.json"
CANDIDATE_PATH = ROOT / "products/power/candidate.json"
IDENTITY_PATH = ROOT / "apps/ios/Power2CandidateIdentity.generated.swift"
RUNNER_CERTIFICATE_CANDIDATE_PATH = (
    ROOT / "products/power/runner-certificates/candidate.json"
)
APP_RELEASE_CANDIDATE_PATH = (
    ROOT / "products/power/app-releases/candidate.json"
)


class Power2RunnerComponentTests(unittest.TestCase):
    def test_component_manifest_is_generated_from_exact_swift_sources(
        self,
    ) -> None:
        dependency_identity = subprocess.run(
            [
                "python3",
                "scripts/generate_power_mlx_dependency_identity.py",
                "--check",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(
            dependency_identity.returncode,
            0,
            dependency_identity.stderr,
        )
        completed = subprocess.run(
            [
                "python3",
                "scripts/generate_power_runner_component_manifest.py",
                "--check",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)

        manifest = json.loads(MANIFEST_PATH.read_text())
        self.assertFalse(manifest["completeForCertification"])
        self.assertIsInstance(
            manifest["components"]["runtimeAdapter"],
            dict,
        )
        for name in (
            "evidenceEnvelope",
            "runnerCore",
            "programModule",
            "targetAdapter",
            "runtimeAdapter",
        ):
            component = manifest["components"][name]
            self.assertTrue(component["files"])
            files = component["files"]
            canonical = json.dumps(
                files,
                sort_keys=True,
                separators=(",", ":"),
            ).encode()
            self.assertEqual(
                component["sha256"],
                hashlib.sha256(canonical).hexdigest(),
            )
            for reference in files:
                path = ROOT / reference["path"]
                self.assertEqual(
                    reference["sha256"],
                    hashlib.sha256(path.read_bytes()).hexdigest(),
                )
        dependency_lock = manifest["resolvedDependencies"]
        self.assertEqual(
            dependency_lock["sha256"],
            hashlib.sha256(
                (ROOT / dependency_lock["path"]).read_bytes()
            ).hexdigest(),
        )
        runtime_identity = manifest["runtimeIdentity"]
        self.assertEqual(
            runtime_identity["sha256"],
            hashlib.sha256(
                (ROOT / runtime_identity["path"]).read_bytes()
            ).hexdigest(),
        )

    def test_candidate_swift_identity_is_generated_and_inactive(self) -> None:
        completed = subprocess.run(
            [
                "python3",
                "scripts/generate_power2_candidate_identity.py",
                "--check",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)

        candidate = json.loads(CANDIDATE_PATH.read_text())
        swift = IDENTITY_PATH.read_text()
        self.assertFalse(candidate["publicIntakeOpen"])
        self.assertIsNone(candidate["appRelease"])
        self.assertIn(candidate["measurementStack"]["sha256"], swift)
        self.assertIn(candidate["runnerCandidate"]["sha256"], swift)
        self.assertIn("static let publicIntakeOpen = false", swift)
        self.assertIn("static let appReleaseAvailable = false", swift)

    def test_release_candidates_are_generated_and_source_bound(self) -> None:
        completed = subprocess.run(
            [
                "python3",
                "scripts/generate_power_release_candidates.py",
                "--check",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)

        candidate = json.loads(CANDIDATE_PATH.read_text())
        runner = json.loads(
            RUNNER_CERTIFICATE_CANDIDATE_PATH.read_text()
        )
        app = json.loads(APP_RELEASE_CANDIDATE_PATH.read_text())
        self.assertEqual(runner["state"], "candidate")
        self.assertEqual(app["state"], "candidate")
        self.assertEqual(
            runner["runnerComponents"],
            candidate["runnerCandidate"],
        )
        self.assertEqual(
            app["appComponents"],
            candidate["appCandidate"],
        )
        self.assertEqual(
            app["sourceRevision"],
            candidate["appCandidate"]["sha256"],
        )
        self.assertEqual(
            app["supportedRunnerCertificationCandidateIDs"],
            [runner["certificateID"]],
        )
        self.assertEqual(
            {
                value
                for key, value in runner["verification"].items()
                if key
                not in {"physicalDeviceSmokeRun", "rawResultReview"}
            },
            {"pass"},
        )
        self.assertEqual(
            runner["verification"]["physicalDeviceSmokeRun"],
            "pending",
        )
        self.assertEqual(
            runner["verification"]["rawResultReview"],
            "pending",
        )
        self.assertEqual(
            app["verification"]["genericIOSReleaseBuild"],
            "pass",
        )
        self.assertEqual(
            app["verification"]["physicalDeviceEndToEndRehearsal"],
            "pending",
        )


if __name__ == "__main__":
    unittest.main()
