from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_ROOT = ROOT / "apps" / "ios"
APP_PROJECT = APP_ROOT / "PowerBenchmarkApp.xcodeproj"
RUNNER_ROOT = ROOT / "apps" / "PowerRunnerKit"
APP_KIT_ROOT = ROOT / "apps" / "PowerAppKit"


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


class Power2AppShellTests(unittest.TestCase):
    def test_candidate_identity_is_generated_and_fail_closed(self) -> None:
        app_manifest = subprocess.run(
            [
                "python3",
                "scripts/generate_power_app_component_manifest.py",
                "--check",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(
            app_manifest.returncode,
            0,
            app_manifest.stderr,
        )
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

        identity = (
            APP_ROOT / "Power2CandidateIdentity.generated.swift"
        ).read_text(encoding="utf-8")
        model = (
            APP_ROOT
            / "PowerBenchmarkApp"
            / "PowerAppModel.swift"
        ).read_text(encoding="utf-8")
        self.assertIn("static let publicIntakeOpen = false", identity)
        self.assertIn("static let appReleaseAvailable = false", identity)
        self.assertIn(
            "Power2CandidateIdentity.appReleaseAvailable",
            model,
        )
        self.assertIn(
            "Power2CandidateIdentity.publicIntakeOpen",
            model,
        )

    def test_app_uses_separate_test_and_results_tabs(self) -> None:
        root_view = (
            APP_ROOT
            / "PowerBenchmarkApp"
            / "PowerRootView.swift"
        ).read_text(encoding="utf-8")
        self.assertIn('Label("Test", systemImage:', root_view)
        self.assertIn('Label("Results", systemImage:', root_view)
        self.assertIn("PowerTestView", root_view)
        self.assertIn("PowerResultsView", root_view)

    def test_app_links_new_local_modules_only(self) -> None:
        project = (APP_PROJECT / "project.pbxproj").read_text(
            encoding="utf-8"
        )
        self.assertIn(
            'XCLocalSwiftPackageReference "../PowerRunnerKit"',
            project,
        )
        self.assertIn(
            'XCLocalSwiftPackageReference "../PowerAppKit"',
            project,
        )
        self.assertNotIn("../ios-app", project)
        self.assertNotIn("power-1.1", project.lower())

    def test_xcode_and_package_dependency_pins_match(self) -> None:
        runner = load_json(RUNNER_ROOT / "Package.resolved")
        app_kit = load_json(APP_KIT_ROOT / "Package.resolved")
        xcode = load_json(
            APP_PROJECT
            / "project.xcworkspace"
            / "xcshareddata"
            / "swiftpm"
            / "Package.resolved"
        )
        self.assertEqual(runner["pins"], app_kit["pins"])
        self.assertEqual(runner["pins"], xcode["pins"])

    def test_github_submission_never_synchronizes_default_fork_branch(
        self,
    ) -> None:
        source = (
            APP_KIT_ROOT
            / "Sources"
            / "PowerGitHubSubmission"
            / "GitHubSubmissionClient.swift"
        ).read_text(encoding="utf-8")
        self.assertNotIn("merge-upstream", source)
        self.assertIn("upstreamReference.object.sha", source)
        self.assertIn('"parents": [upstreamReference.object.sha]', source)


if __name__ == "__main__":
    unittest.main()
