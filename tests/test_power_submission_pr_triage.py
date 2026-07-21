from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from scripts.power import create_package
from scripts.triage_power_submission_pr import _changes, classify


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = (
    ROOT
    / "results/suite-b-power-1.1.0-rc.1/device-verification/raw/"
    "2026-07-15T15-25-48Z_b-ux-001-short-interaction_"
    "mlx-community-qwen3-0.6b-4bit_iphone15-3_21b5f28f.json"
)
SUBMISSION_ID = "11111111-2222-4333-8444-555555555555"
PREFIX = "submissions/suite-b/power-1.1.0/draft"


class PowerSubmissionPRTriageTests(unittest.TestCase):
    def make_package(
        self,
        root: Path,
        *,
        contributor: str = "ExampleContributor",
        conflict: str = "none",
        thermal: str = "none",
    ) -> Path:
        result = json.loads(FIXTURE.read_text())
        result["resultID"] = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"
        result["execution"]["sessionID"] = "bbbbbbbb-cccc-4ddd-8eee-ffffffffffff"
        result_path = root / "candidate-result.json"
        result_path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
        statement = (
            "No conflict of interest disclosed."
            if conflict == "none"
            else "Contributor works for the model publisher."
        )
        return create_package(
            result_path,
            root / "packages",
            contributor,
            declarations_accepted=True,
            conflict_category=conflict,
            conflict_statement=statement,
            thermal_assistance=thermal,
            submission_id=SUBMISSION_ID,
            created_at="2026-07-15T16:00:00Z",
        )

    def classify_package(self, package: Path) -> dict:
        changes = [
            ("A", f"{PREFIX}/{SUBMISSION_ID}/result.json"),
            ("A", f"{PREFIX}/{SUBMISSION_ID}/submission.json"),
        ]

        def materialize(_head: str, _submission: str, root: Path) -> Path:
            target = root / SUBMISSION_ID
            shutil.copytree(package, target)
            return target

        with mock.patch(
            "scripts.triage_power_submission_pr._changes", return_value=changes
        ), mock.patch(
            "scripts.triage_power_submission_pr._materialize_package",
            side_effect=materialize,
        ):
            return classify("base", "head", "ExampleContributor")

    def test_clean_metric_eligible_package_is_auto_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            report = self.classify_package(self.make_package(Path(temporary)))
        self.assertEqual(report["classification"], "auto_accept")
        self.assertEqual(report["packageCount"], 1)
        self.assertTrue(report["packages"][0]["performanceRankingEligible"])

    def test_disclosed_conflict_routes_to_manual_review(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            package = self.make_package(Path(temporary), conflict="model-affiliated")
            report = self.classify_package(package)
        self.assertEqual(report["classification"], "manual_review")
        self.assertIn(
            "conflict_disclosure_requires_review", report["reasonCodes"]
        )

    def test_non_submission_change_is_not_applicable(self) -> None:
        with mock.patch(
            "scripts.triage_power_submission_pr._changes",
            return_value=[("M", "README.md")],
        ):
            report = classify("base", "head", "ExampleContributor")
        self.assertEqual(report["classification"], "not_applicable")

    def test_submission_mixed_with_other_changes_is_rejected(self) -> None:
        changes = [
            ("A", f"{PREFIX}/{SUBMISSION_ID}/result.json"),
            ("A", f"{PREFIX}/{SUBMISSION_ID}/submission.json"),
            ("M", "README.md"),
        ]
        with mock.patch(
            "scripts.triage_power_submission_pr._changes", return_value=changes
        ):
            report = classify("base", "head", "ExampleContributor")
        self.assertEqual(report["classification"], "rejected")
        self.assertIn("pull_request_scope_invalid", report["reasonCodes"])

    def test_changes_are_measured_from_the_pull_request_merge_base(self) -> None:
        with mock.patch(
            "scripts.triage_power_submission_pr._git",
            return_value=b"A\tREADME.md\n",
        ) as git:
            self.assertEqual(_changes("base", "head"), [("A", "README.md")])
        git.assert_called_once_with(
            "diff", "--name-status", "--no-renames", "base...head"
        )

    def test_unsafe_submission_directory_is_rejected(self) -> None:
        changes = [
            ("A", f"{PREFIX}/../result.json"),
            ("A", f"{PREFIX}/../submission.json"),
        ]
        with mock.patch(
            "scripts.triage_power_submission_pr._changes", return_value=changes
        ):
            report = classify("base", "head", "ExampleContributor")
        self.assertEqual(report["classification"], "rejected")


if __name__ == "__main__":
    unittest.main()
