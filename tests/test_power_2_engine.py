from __future__ import annotations

import copy
import hashlib
import json
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path

from scripts.lib.power2 import json_schema
from scripts.lib.power2.engine import (
    ROOT,
    load_candidate_context,
    validate_package,
)


EVALUATED_AT = "2026-07-23T12:00:00Z"
VALIDATOR_SOURCE_REVISION = "a" * 40
APP_SOURCE_REVISION = "b" * 40
SUBMISSION_ID = "44444444-4444-4444-8444-444444444444"
RESULT_ID = "55555555-5555-4555-8555-555555555555"
RUNNER_CERTIFICATE_ID = "power2-test-fixture-certificate"


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


class Power2EngineTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.candidate_context = load_candidate_context()
        cls.trusted_context = replace(
            cls.candidate_context,
            public_intake_open=True,
            runner_certificate={
                "certificateID": RUNNER_CERTIFICATE_ID,
                "state": "active",
                "programManifestSHA256": cls.candidate_context.program_reference[
                    "sha256"
                ],
                "targetManifestSHA256": cls.candidate_context.target_reference[
                    "sha256"
                ],
            },
            app_release={
                "state": "supported",
                "version": "2.0-test-fixture",
                "build": "1",
                "sourceRevision": APP_SOURCE_REVISION,
                "supportedRunnerCertificateIDs": [
                    RUNNER_CERTIFICATE_ID
                ],
            },
        )

    def make_result(self) -> dict:
        context = self.trusted_context
        model_manifest, model_digest = next(
            iter(context.model_entries.values())
        )
        workload, workload_digest = context.workloads[
            "power.text.short-interaction"
        ]
        attempts = []
        for index in range(6):
            token_events = []
            for token_index in range(24):
                received = (
                    100
                    if token_index == 0
                    else 110 + round(790 * (token_index - 1) / 22)
                )
                if token_index == 0:
                    decoded_at = 105
                    decoded_prefix = " "
                    is_special = False
                    is_renderable = False
                elif token_index == 1:
                    decoded_at = 120
                    decoded_prefix = "The"
                    is_special = False
                    is_renderable = True
                else:
                    decoded_at = None
                    decoded_prefix = None
                    is_special = None
                    is_renderable = None
                token_events.append(
                    {
                        "index": token_index,
                        "tokenID": token_index + 1,
                        "receivedNanoseconds": received,
                        "decodedAtNanoseconds": decoded_at,
                        "decodedPrefix": decoded_prefix,
                        "isSpecial": is_special,
                        "isRenderable": is_renderable,
                    }
                )
            attempts.append(
                {
                    "index": index,
                    "phase": "warmup" if index == 0 else "measured",
                    "outcome": "succeeded",
                    "startedAt": f"2026-07-23T12:00:0{index}Z",
                    "endedAt": f"2026-07-23T12:00:1{index}Z",
                    "monotonic": {
                        "clock": "continuous-clock",
                        "requestAcceptedNanoseconds": 0,
                        "firstTokenNanoseconds": 100,
                        "firstRenderableNanoseconds": 120,
                        "completedNanoseconds": 1_000,
                        "promptEvaluationNanoseconds": 100,
                        "decodeNanoseconds": 800,
                    },
                    "tokenCounts": {"input": 20, "output": 24},
                    "tokenEvents": token_events,
                    "generatedText": (
                        "The note is stored locally and safely. "
                        "Synchronization resumes when connectivity returns."
                    ),
                    "memory": {
                        "peakPhysicalFootprintBytes": 500_000_000,
                        "samples": [
                            {
                                "elapsedNanoseconds": 0,
                                "physicalFootprintBytes": 450_000_000,
                            },
                            {
                                "elapsedNanoseconds": 500,
                                "physicalFootprintBytes": 500_000_000,
                            },
                        ],
                    },
                    "thermal": {
                        "start": "nominal",
                        "end": "nominal",
                        "transitions": [],
                    },
                    "failure": None,
                }
            )
        return {
            "schemaVersion": "power-evidence-envelope-1.0.0-draft.1",
            "resultID": RESULT_ID,
            "createdAt": "2026-07-23T11:59:00Z",
            "productID": "power",
            "program": {
                "id": context.program_reference["id"],
                "version": context.program_reference["version"],
                "manifestSHA256": context.program_reference["sha256"],
            },
            "target": {
                "id": context.target_reference["id"],
                "version": context.target_reference["version"],
                "manifestSHA256": context.target_reference["sha256"],
            },
            "runnerCertificateID": RUNNER_CERTIFICATE_ID,
            "appRelease": {
                "version": "2.0-test-fixture",
                "build": "1",
                "sourceRevision": APP_SOURCE_REVISION,
                "embeddedMeasurementStackSHA256": (
                    context.measurement_stack_sha256
                ),
            },
            "model": {
                "registryEntryID": model_manifest["registryEntryID"],
                "registryEntrySHA256": model_digest,
                "artifactID": model_manifest["artifactID"],
                "artifactRevision": model_manifest["artifactRevision"],
                "parameterCount": model_manifest["parameterCount"],
                "quantization": model_manifest["quantization"],
                "format": model_manifest["format"],
            },
            "runtime": {
                "name": "MLX Swift LM",
                "version": "test-fixture",
                "resolvedRevision": "c" * 40,
                "backend": "MLX/Metal",
                "configuration": {"fixture": True},
            },
            "device": {
                "machineIdentifier": "iPhone-test-fixture",
                "osVersion": "test-fixture",
                "osBuild": "test-fixture",
            },
            "environment": {
                "batteryLevelAtStart": 0.8,
                "batteryStateAtStart": "unplugged",
                "lowPowerModeAtStart": False,
                "thermalStateAtStart": "nominal",
                "thermalStateAtEnd": "nominal",
                "thermalAssistance": "none",
            },
            "artifacts": [],
            "payload": {
                "schemaVersion": (
                    "power-text-generation-payload-1.0.0-draft.1"
                ),
                "workload": {
                    "id": workload["workloadID"],
                    "version": workload["workloadVersion"],
                    "sha256": workload_digest,
                },
                "measurementMode": workload["measurementMode"],
                "inferenceConfiguration": workload["generation"],
                "attempts": attempts,
            },
        }

    def make_submission(self, result_bytes: bytes) -> dict:
        model_manifest, _ = next(
            iter(self.trusted_context.model_entries.values())
        )
        return {
            "schemaVersion": "power-submission-1.0.0-draft.1",
            "submissionID": SUBMISSION_ID,
            "createdAt": "2026-07-23T11:59:30Z",
            "contributor": {
                "githubLogin": "power-fixture-user",
                "conflictOfInterest": "none",
            },
            "sourceResult": {
                "path": "result.json",
                "sha256": sha256_bytes(result_bytes),
                "schemaVersion": (
                    "power-evidence-envelope-1.0.0-draft.1"
                ),
            },
            "declarations": {
                "physicalDevice": True,
                "publicMetadataReviewed": True,
                "rawEvidenceUnmodified": True,
                "containsNoPersonalData": True,
                "licenseAccepted": "CC-BY-4.0",
                "rankingNotGuaranteed": True,
            },
            "environmentNotes": (
                "Clearly labeled synthetic unit-test fixture; not evidence "
                f"for {model_manifest['displayName']}."
            ),
        }

    def write_package(
        self,
        parent: Path,
        result: dict,
        *,
        submission_override: dict | None = None,
    ) -> Path:
        package = parent / SUBMISSION_ID
        package.mkdir()
        result_bytes = (
            json.dumps(result, indent=2, sort_keys=True) + "\n"
        ).encode()
        submission = submission_override or self.make_submission(result_bytes)
        (package / "result.json").write_bytes(result_bytes)
        (package / "submission.json").write_text(
            json.dumps(submission, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        return package

    def validate(self, package: Path, *, context=None) -> dict:
        return validate_package(
            package,
            context=context or self.trusted_context,
            evaluated_at=EVALUATED_AT,
            validator_source_revision=VALIDATOR_SOURCE_REVISION,
            pr_author="Power-Fixture-User",
        )

    def test_valid_new_package_is_deterministically_auto_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.write_package(Path(directory), self.make_result())
            first = self.validate(package)
            second = self.validate(package)

        self.assertEqual(first, second)
        self.assertEqual(first["classification"], "auto-accept")
        self.assertEqual(first["reasonCodes"], [])
        self.assertTrue(
            all(
                check["status"] == "pass"
                for check in first["checks"]["metricEligibility"].values()
                if check["reasonCodes"]
                != ["metric-not-defined-for-workload"]
            )
        )

    def test_failed_oom_and_cancelled_attempts_remain_accepted_evidence(self) -> None:
        result = self.make_result()
        outcomes = ["failed", "oom", "cancelled", "not-run", "failed"]
        for attempt, outcome in zip(
            result["payload"]["attempts"][1:], outcomes
        ):
            attempt["outcome"] = outcome
            attempt["monotonic"] = {
                "clock": "continuous-clock",
                "requestAcceptedNanoseconds": attempt["monotonic"][
                    "requestAcceptedNanoseconds"
                ],
            }
            attempt["tokenCounts"] = {"input": 0, "output": 0}
            attempt["tokenEvents"] = []
            attempt["generatedText"] = ""
            attempt["memory"] = {
                "peakPhysicalFootprintBytes": None,
                "samples": [],
            }
            attempt["failure"] = {
                "code": outcome,
                "message": f"synthetic {outcome} fixture",
            }

        with tempfile.TemporaryDirectory() as directory:
            package = self.write_package(Path(directory), result)
            report = self.validate(package)

        self.assertEqual(report["classification"], "auto-accept")
        self.assertEqual(
            report["checks"]["contractConformance"]["status"], "pass"
        )
        self.assertTrue(
            all(
                check["status"] == "not-applicable"
                for check in report["checks"]["metricEligibility"].values()
            )
        )

    def test_changed_result_bytes_fail_digest_integrity(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.write_package(Path(directory), self.make_result())
            result = json.loads((package / "result.json").read_text())
            result["device"]["osBuild"] = "tampered"
            (package / "result.json").write_text(
                json.dumps(result, indent=2, sort_keys=True) + "\n"
            )
            report = self.validate(package)

        self.assertEqual(report["classification"], "reject")
        self.assertIn("result-digest-mismatch", report["reasonCodes"])

    def test_raw_summaries_must_recalculate_from_retained_samples(self) -> None:
        result = self.make_result()
        attempt = result["payload"]["attempts"][1]
        attempt["monotonic"]["firstRenderableNanoseconds"] = 121
        attempt["memory"]["peakPhysicalFootprintBytes"] = 499_999_999

        with tempfile.TemporaryDirectory() as directory:
            package = self.write_package(Path(directory), result)
            report = self.validate(package)

        self.assertEqual(report["classification"], "reject")
        self.assertIn("raw-attempt-inconsistent", report["reasonCodes"])
        self.assertTrue(
            any(
                "cannot be reproduced" in diagnostic
                for diagnostic in report["diagnostics"]
            )
        )

    def test_renderability_probing_stops_after_first_renderable_event(
        self,
    ) -> None:
        result = self.make_result()
        event = result["payload"]["attempts"][1]["tokenEvents"][2]
        event.update(
            {
                "decodedAtNanoseconds": 130,
                "decodedPrefix": "later",
                "isSpecial": False,
                "isRenderable": True,
            }
        )

        with tempfile.TemporaryDirectory() as directory:
            package = self.write_package(Path(directory), result)
            report = self.validate(package)

        self.assertEqual(report["classification"], "reject")
        self.assertIn("raw-attempt-inconsistent", report["reasonCodes"])
        self.assertTrue(
            any(
                "after the first renderable event" in diagnostic
                for diagnostic in report["diagnostics"]
            )
        )

    def test_power_1_package_is_rejected_without_translation(self) -> None:
        result = {"schemaVersion": "suite-b-power-result-1.1.0"}
        result_bytes = (json.dumps(result) + "\n").encode()
        submission = {
            "schemaVersion": "suite-b-power-submission-1.1.0",
            "submissionID": SUBMISSION_ID,
            "sourceResult": {
                "path": "result.json",
                "sha256": sha256_bytes(result_bytes),
                "schemaVersion": "suite-b-power-result-1.1.0",
            },
        }
        with tempfile.TemporaryDirectory() as directory:
            package = self.write_package(
                Path(directory),
                result,
                submission_override=submission,
            )
            report = self.validate(package)

        self.assertEqual(report["classification"], "reject")
        self.assertIn("unsupported-major-version", report["reasonCodes"])
        self.assertNotIn("translated", " ".join(report["diagnostics"]).lower())

    def test_real_candidate_stays_closed_until_runner_and_app_exist(self) -> None:
        result = self.make_result()
        with tempfile.TemporaryDirectory() as directory:
            package = self.write_package(Path(directory), result)
            report = self.validate(
                package, context=self.candidate_context
            )

        self.assertEqual(report["classification"], "reject")
        self.assertIn("runner-certificate-not-active", report["reasonCodes"])
        self.assertIn("app-release-not-supported", report["reasonCodes"])
        self.assertIn("public-intake-closed", report["reasonCodes"])

    def test_registered_model_snapshot_cannot_be_changed(self) -> None:
        result = self.make_result()
        result["model"]["parameterCount"] += 1
        with tempfile.TemporaryDirectory() as directory:
            package = self.write_package(Path(directory), result)
            report = self.validate(package)

        self.assertEqual(report["classification"], "reject")
        self.assertIn(
            "model-artifact-identity-mismatch", report["reasonCodes"]
        )

    def test_json_schema_rejects_unknown_envelope_fields(self) -> None:
        result = self.make_result()
        result["legacyCompatibility"] = True
        errors = json_schema.validate(
            result,
            self.trusted_context.schema_paths["evidence"],
            ROOT,
        )

        self.assertTrue(
            any("unexpected property 'legacyCompatibility'" in error for error in errors)
        )

    def test_pr_author_must_match_declared_contributor(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.write_package(Path(directory), self.make_result())
            report = validate_package(
                package,
                context=self.trusted_context,
                evaluated_at=EVALUATED_AT,
                validator_source_revision=VALIDATOR_SOURCE_REVISION,
                pr_author="different-user",
            )

        self.assertEqual(report["classification"], "reject")
        self.assertIn("contributor-identity-mismatch", report["reasonCodes"])


if __name__ == "__main__":
    unittest.main()
