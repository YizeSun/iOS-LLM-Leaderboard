from __future__ import annotations

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "models" / "power-test-catalog.json"
SWIFT_PROFILE_PATH = ROOT / "ios-app" / "BenchmarkApp" / "PilotPlan.swift"


class PowerModelCatalogTests(unittest.TestCase):
    def setUp(self) -> None:
        self.catalog = json.loads(CATALOG_PATH.read_text())

    def test_catalog_contains_eight_unique_unmeasured_candidates(self) -> None:
        models = self.catalog["models"]
        self.assertEqual([model["recommendedPriority"] for model in models], list(range(1, 9)))
        self.assertEqual(len({model["artifactID"] for model in models}), 8)
        self.assertTrue(all(model["physicalDeviceEvidenceStatus"] == "untested" for model in models))
        self.assertTrue(all(model["runtimeRegistryStatus"] == "registered-not-device-verified" for model in models))
        self.assertTrue(all(re.fullmatch(r"[0-9a-f]{40}", model["artifactRevision"]) for model in models))
        self.assertTrue(all(model["artifactRevision"] in model["sourceURL"] for model in models))
        catalog_keys = {
            key.casefold()
            for group in ("models", "compatibilityReview", "reviewedIneligible")
            for entry in self.catalog[group]
            for key in entry
        }
        for forbidden in (
            "ttft",
            "decodetokenspersecond",
            "prefilltokenspersecond",
            "rank",
            "score",
        ):
            self.assertNotIn(forbidden, catalog_keys)

    def test_catalog_contains_four_small_compatibility_reviews(self) -> None:
        review = self.catalog["compatibilityReview"]
        self.assertEqual(
            [model["artifactID"] for model in review],
            [
                "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit",
                "mlx-community/Qwen3.5-2B-4bit",
                "mlx-community/AI21-Jamba-Reasoning-3B-4bit",
                "mlx-community/OpenELM-270M-Instruct",
            ],
        )
        self.assertEqual([model["reviewPriority"] for model in review], [1, 2, 3, 4])
        self.assertTrue(all(model["physicalDeviceEvidenceStatus"] == "not-app-testable" for model in review))
        self.assertTrue(all(model["blockerCode"] for model in review))
        self.assertTrue(all(re.fullmatch(r"[0-9a-f]{40}", model["artifactRevision"]) for model in review))
        self.assertTrue(all(model["artifactRevision"] in model["sourceURL"] for model in review))
        self.assertFalse(self.catalog["compatibilityReviewPolicy"]["appSelectable"])
        self.assertFalse(self.catalog["compatibilityReviewPolicy"]["rankingEligible"])
        self.assertTrue(self.catalog["compatibilityReviewPolicy"]["publicDisplay"])

    def test_large_reviewed_models_are_preserved_but_not_publicly_displayed(self) -> None:
        excluded = self.catalog["reviewedIneligible"]
        self.assertEqual(
            [model["officialModelID"] for model in excluded],
            [
                "zai-org/GLM-5.2",
                "zai-org/GLM-5.1",
                "moonshotai/Kimi-K2.7-Code",
                "deepseek-ai/DeepSeek-V4-Pro",
                "moonshotai/Kimi-K2.6",
                "XiaomiMiMo/MiMo-V2.5-Pro",
                "MiniMaxAI/MiniMax-M3",
                "deepseek-ai/DeepSeek-V4-Flash",
                "MiniMaxAI/MiniMax-M2.7",
                "google/gemma-4-31B-it",
                "nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B-NVFP4",
            ],
        )
        self.assertEqual(len({model["officialModelID"] for model in excluded}), 11)
        self.assertTrue(all(model["licenseIdentifier"] for model in excluded))
        self.assertTrue(all(model["appEligibility"] == "not-app-testable" for model in excluded))
        self.assertTrue(all(model["officialModelID"] in model["sourceURL"] for model in excluded))
        self.assertTrue(all(model["licenseSourceURL"].startswith("https://") for model in excluded))
        self.assertFalse(self.catalog["reviewedIneligiblePolicy"]["appSelectable"])
        self.assertFalse(self.catalog["reviewedIneligiblePolicy"]["rankingEligible"])
        self.assertFalse(self.catalog["reviewedIneligiblePolicy"]["publicDisplay"])

    def test_catalog_runtime_matches_the_locked_app_dependency(self) -> None:
        package = json.loads(
            (
                ROOT
                / "ios-app"
                / "BenchmarkApp.xcodeproj"
                / "project.xcworkspace"
                / "xcshareddata"
                / "swiftpm"
                / "Package.resolved"
            ).read_text()
        )
        pin = next(item for item in package["pins"] if item["identity"] == "mlx-swift-lm")
        self.assertEqual(self.catalog["runtime"]["version"], pin["state"]["version"])
        self.assertEqual(self.catalog["runtime"]["revision"], pin["state"]["revision"])

    def test_every_catalog_artifact_is_selectable_in_the_candidate_app(self) -> None:
        swift = SWIFT_PROFILE_PATH.read_text()
        for model in self.catalog["models"]:
            self.assertIn(f'artifactId: "{model["artifactID"]}"', swift)
            self.assertIn(f'artifactRevision: "{model["artifactRevision"]}"', swift)
        project = (ROOT / "ios-app" / "BenchmarkApp.xcodeproj" / "project.pbxproj").read_text()
        self.assertEqual(project.count("MARKETING_VERSION = 0.10.0;"), 2)
        self.assertEqual(project.count("CURRENT_PROJECT_VERSION = 12;"), 2)

    def test_review_only_models_are_not_misrepresented_as_app_options(self) -> None:
        swift = SWIFT_PROFILE_PATH.read_text()
        for group in ("compatibilityReview", "reviewedIneligible"):
            for model in self.catalog[group]:
                identity = model.get("artifactID", model.get("officialModelID"))
                self.assertNotIn(identity, swift)

    def test_untested_candidates_are_absent_from_all_ranking_data(self) -> None:
        candidate_ids = {model["artifactID"] for model in self.catalog["models"]}
        candidate_ids.update(model["artifactID"] for model in self.catalog["compatibilityReview"])
        candidate_ids.update(model["officialModelID"] for model in self.catalog["reviewedIneligible"])
        for relative in (
            "results/suite-b-power-1.0/normalized-results.json",
            "results/suite-b-power-community/normalized-results.json",
        ):
            data = json.loads((ROOT / relative).read_text())
            ranked_ids = {
                row["configuration"]["model"]["artifactID"]
                for row in data["results"]
            }
            self.assertTrue(candidate_ids.isdisjoint(ranked_ids))

    def test_site_exposes_a_separate_non_ranking_catalog(self) -> None:
        index = (ROOT / "index.html").read_text()
        app = (ROOT / "site" / "app.js").read_text()
        self.assertIn('data-mode="catalog"', index)
        self.assertIn("models/power-test-catalog.json", app)
        self.assertIn("These are not rankings", app)
        self.assertIn("No performance claims", app)
        self.assertIn("Needs review", app)
        self.assertIn("compatibilityReview", app)
        self.assertNotIn("catalog.reviewedIneligible", app)

    def test_candidate_source_and_contributor_guide_are_pinned(self) -> None:
        source_commit = "e084a562f94201208ee897a4dda58f18ddec0a54"
        self.assertEqual(self.catalog["referenceApp"]["sourceCommit"], source_commit)
        guide = (ROOT / "contributor-kit" / "test-recommended-model.md").read_text()
        self.assertIn(source_commit, guide)
        self.assertIn("Export Raw JSON", guide)
        self.assertIn("create_suite_b_power_submission.py", guide)
        self.assertIn("do not manufacture JSON", guide)


if __name__ == "__main__":
    unittest.main()
