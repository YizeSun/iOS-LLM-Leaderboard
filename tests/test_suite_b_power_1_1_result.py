from __future__ import annotations

import copy
import hashlib
import json
import unittest
from pathlib import Path

from scripts.validate_suite_b_power_1_1_result import (
    validate,
    validate_report_shape,
    verify_draft_assets,
)
from tests.test_suite_b_power_result import refresh_summary, valid_result


ROOT = Path(__file__).resolve().parents[1]
REASON_REGISTRY = (
    ROOT
    / "benchmarks/suite-b-on-device-performance/power-1.1-validation-reasons.json"
)


def power_1_1_result(
    workload_id: str = "b-pipe-001-sustained-generation",
) -> dict:
    result = valid_result(workload_id)
    result["schemaVersion"] = "suite-b-power-result-1.1.0-draft.1"
    result["benchmarkRelease"]["version"] = "1.1.0-draft.1"
    result["benchmarkRelease"]["protocolVersion"] = "1.1.0-draft.1"
    result["execution"]["workloadVersion"] = "1.1.0-draft.1"
    return result


def result_digest(result: dict) -> str:
    raw = json.dumps(result, separators=(",", ":"), sort_keys=True).encode()
    return hashlib.sha256(raw).hexdigest()


def report_for(result: dict) -> dict:
    return validate(result, result_digest(result))


def report_reason_codes(report: object) -> set[str]:
    if isinstance(report, dict):
        found = set(report.get("reasonCodes", []))
        for value in report.values():
            found.update(report_reason_codes(value))
        return found
    if isinstance(report, list):
        return {
            reason
            for value in report
            for reason in report_reason_codes(value)
        }
    return set()


class PowerOneOneResultValidatorTests(unittest.TestCase):
    def test_draft_assets_are_digest_pinned(self) -> None:
        self.assertEqual(verify_draft_assets(), [])

    def test_valid_short_interaction_keeps_measurement_and_behavior_separate(self) -> None:
        result = power_1_1_result("b-ux-001-short-interaction")
        digest = result_digest(result)
        report = validate(result, digest)

        self.assertEqual(validate_report_shape(report), [])
        self.assertEqual(report["result"]["sha256"], digest)
        self.assertTrue(report["structuralValidity"]["valid"])
        self.assertTrue(report["protocolConformance"]["valid"])
        self.assertTrue(
            report["metricEligibility"]["first_renderable_proxy_ttft_ms@1"][
                "eligible"
            ]
        )
        self.assertEqual(report["behaviorConformance"]["status"], "verified")
        self.assertFalse(report["performanceRankingEligibility"]["eligible"])
        self.assertIn(
            "protocol_draft_not_rank_authorized",
            report["performanceRankingEligibility"]["reasonCodes"],
        )

    def test_correct_synonym_is_not_verified_without_losing_metrics(self) -> None:
        result = power_1_1_result("b-ux-001-short-interaction")
        for attempt in result["attempts"][1:]:
            attempt["generatedText"] = (
                "Your note is securely stored on this device. "
                "It will sync when connectivity returns."
            )

        report = report_for(result)

        self.assertTrue(report["protocolConformance"]["valid"])
        self.assertEqual(report["behaviorConformance"]["status"], "not_verified")
        self.assertEqual(
            report["behaviorConformance"]["reasonCodes"],
            ["behavior_not_verified"],
        )
        self.assertTrue(
            report["metricEligibility"]["first_renderable_proxy_ttft_ms@1"][
                "eligible"
            ]
        )
        self.assertNotIn(
            "behavior_not_verified",
            report["metricEligibility"]["first_renderable_proxy_ttft_ms@1"][
                "reasonCodes"
            ],
        )
        self.assertIn(
            "behavior_verification_required",
            report["recommendationEligibility"]["reasonCodes"],
        )

    def test_app_behavior_assessment_is_advisory_only(self) -> None:
        result = power_1_1_result("b-ux-001-short-interaction")
        for attempt in result["attempts"]:
            attempt["responseConformance"] = {
                "status": "fail",
                "reasonCodes": ["response_conformance_failed"],
            }

        report = report_for(result)

        self.assertTrue(report["protocolConformance"]["valid"])
        self.assertEqual(report["behaviorConformance"]["status"], "verified")

    def test_behavior_gated_null_metrics_are_rejected(self) -> None:
        result = power_1_1_result("b-ux-001-short-interaction")
        for attempt in result["attempts"][1:]:
            attempt["responseConformance"] = {
                "status": "fail",
                "reasonCodes": ["response_conformance_failed"],
            }
            attempt["derivedMetrics"] = {
                key: None for key in attempt["derivedMetrics"]
            }
        refresh_summary(result)

        report = report_for(result)

        self.assertFalse(report["protocolConformance"]["valid"])
        self.assertIn(
            "aggregate_mismatch", report["protocolConformance"]["reasonCodes"]
        )
        self.assertTrue(
            report["metricEligibility"]["first_renderable_proxy_ttft_ms@1"][
                "eligible"
            ]
        )

    def test_pipeline_behavior_is_not_applicable(self) -> None:
        report = report_for(power_1_1_result())

        self.assertTrue(report["protocolConformance"]["valid"])
        self.assertEqual(
            report["behaviorConformance"],
            {
                "applicable": False,
                "policyID": None,
                "status": None,
                "reasonCodes": [],
            },
        )
        self.assertEqual(validate_report_shape(report), [])

    def test_structurally_invalid_result_still_emits_a_valid_minimal_report(self) -> None:
        result = power_1_1_result()
        del result["model"]["displayName"]

        report = report_for(result)

        self.assertFalse(report["structuralValidity"]["valid"])
        self.assertFalse(report["protocolConformance"]["valid"])
        self.assertEqual(report["metricEligibility"], {})
        self.assertEqual(validate_report_shape(report), [])

    def test_tampered_token_identity_is_protocol_invalid(self) -> None:
        result = power_1_1_result()
        result["attempts"][2]["tokenEvents"][1]["index"] = 7

        report = report_for(result)

        self.assertFalse(report["protocolConformance"]["valid"])
        self.assertIn(
            "token_evidence_invalid", report["protocolConformance"]["reasonCodes"]
        )

    def test_behavior_uses_three_of_five_measured_attempts(self) -> None:
        result = power_1_1_result("b-ux-001-short-interaction")
        nonmatching = "Done."
        for attempt in result["attempts"][1:3]:
            attempt["generatedText"] = nonmatching
        self.assertEqual(
            report_for(result)["behaviorConformance"]["status"], "verified"
        )

        result["attempts"][3]["generatedText"] = nonmatching
        self.assertEqual(
            report_for(result)["behaviorConformance"]["status"], "not_verified"
        )

    def test_report_reason_codes_are_registered(self) -> None:
        registry = set(json.loads(REASON_REGISTRY.read_text())["reason_codes"])
        reports = [
            report_for(power_1_1_result()),
            report_for(power_1_1_result("b-ux-001-short-interaction")),
        ]
        invalid = power_1_1_result()
        invalid["environment"]["batteryLevelPercentAtStart"] = 20
        reports.append(report_for(invalid))
        for report in reports:
            self.assertLessEqual(report_reason_codes(report), registry)

    def test_validation_is_deterministic_and_does_not_mutate_result(self) -> None:
        result = power_1_1_result("b-ux-001-short-interaction")
        original = copy.deepcopy(result)
        digest = result_digest(result)

        self.assertEqual(validate(result, digest), validate(result, digest))
        self.assertEqual(result, original)


if __name__ == "__main__":
    unittest.main()
