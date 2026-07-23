from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_ROOT = ROOT / "apps" / "ios"
APP_PROJECT = APP_ROOT / "PowerBenchmarkApp.xcodeproj"
CERTIFICATION_SCHEME = (
    APP_PROJECT
    / "xcshareddata"
    / "xcschemes"
    / "PowerCertification.xcscheme"
)
OFFICIAL_SCHEME = (
    APP_PROJECT
    / "xcshareddata"
    / "xcschemes"
    / "PowerOfficial.xcscheme"
)
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

    def test_certification_catalog_is_generated_from_candidate(self) -> None:
        completed = subprocess.run(
            [
                "python3",
                "scripts/generate_power2_app_catalog.py",
                "--check",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)

        catalog = (
            APP_ROOT / "Power2CandidateCatalog.generated.swift"
        ).read_text(encoding="utf-8")
        registry = load_json(ROOT / "models" / "registry.json")
        for entry in registry["entries"]:
            model = load_json(ROOT / entry["path"])
            self.assertIn(
                f'id: "{model["registryEntryID"]}"',
                catalog,
            )
        self.assertIn("power2-certification-candidate-", catalog)

    def test_certification_build_is_isolated_and_source_bound(self) -> None:
        project = (APP_PROJECT / "project.pbxproj").read_text(
            encoding="utf-8"
        )
        scheme = CERTIFICATION_SCHEME.read_text(encoding="utf-8")
        identity = (
            APP_ROOT
            / "PowerBenchmarkApp"
            / "PowerAppBuildIdentity.swift"
        ).read_text(encoding="utf-8")
        info_plist = (
            APP_ROOT / "PowerBenchmarkApp" / "Info.plist"
        ).read_text(encoding="utf-8")
        model = (
            APP_ROOT
            / "PowerBenchmarkApp"
            / "PowerAppModel.swift"
        ).read_text(encoding="utf-8")

        self.assertEqual(project.count("POWER_CERTIFICATION"), 1)
        self.assertIn('buildConfiguration = "Certification"', scheme)
        self.assertIn('allowLocationSimulation = "NO"', scheme)
        self.assertIn('SUPPORTED_PLATFORMS = "iphoneos";', project)
        self.assertIn("PowerSourceRevision", identity)
        self.assertIn("isValidSourceRevision", identity)
        self.assertIn("<key>PowerSourceRevision</key>", info_plist)
        self.assertIn(
            "<string>$(POWER_SOURCE_REVISION)</string>",
            info_plist,
        )
        self.assertIn("AppleIPhoneTargetAdapter()", model)
        self.assertIn("PowerRunner(runtime: runtime, target: target)", model)
        self.assertIn("PowerEvidenceEnvelope(", model)
        self.assertIn("store.save(envelope: envelope)", model)

    def test_signing_is_local_and_build_kinds_are_fail_closed(self) -> None:
        project = (APP_PROJECT / "project.pbxproj").read_text(
            encoding="utf-8"
        )
        signing = (
            APP_ROOT / "Configuration" / "Signing.xcconfig"
        ).read_text(encoding="utf-8")
        official_scheme = OFFICIAL_SCHEME.read_text(encoding="utf-8")
        identity = (
            APP_ROOT
            / "PowerBenchmarkApp"
            / "PowerAppBuildIdentity.swift"
        ).read_text(encoding="utf-8")
        model = (
            APP_ROOT
            / "PowerBenchmarkApp"
            / "PowerAppModel.swift"
        ).read_text(encoding="utf-8")

        self.assertNotIn("DEVELOPMENT_TEAM =", project)
        self.assertIn("LocalSigning.xcconfig", signing)
        self.assertIn("POWER_BUILD_KIND = developer", project)
        self.assertIn("POWER_BUILD_KIND = certification", project)
        self.assertIn("POWER_BUILD_KIND = official", project)
        self.assertEqual(project.count("POWER_OFFICIAL"), 1)
        self.assertIn('buildConfiguration = "Official"', official_scheme)
        self.assertIn("case developer", identity)
        self.assertIn("case certification", identity)
        self.assertIn("case official", identity)
        self.assertIn("declaredKind == compiledKind", identity)
        self.assertIn(
            "PowerAppBuildIdentity.officialReleaseAvailable",
            model,
        )

        ignored = subprocess.run(
            [
                "git",
                "check-ignore",
                "apps/ios/Configuration/LocalSigning.xcconfig",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(ignored.returncode, 0, ignored.stderr)

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
