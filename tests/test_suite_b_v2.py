from __future__ import annotations

import json
import unittest
from pathlib import Path

from scripts.validate_suite_b_bundle import validate
from scripts.validate_suite_b_workload import validate as validate_workload


ROOT = Path(__file__).resolve().parents[1]
WORKLOADS = ROOT / "benchmarks" / "suite-b-on-device-performance" / "workloads"


def attempt(run_index: int, role: str, scale: float = 1.0) -> dict:
    first = int(100_000_000 * scale)
    second = first + int(20_000_000 * scale)
    third = second + int(20_000_000 * scale)
    decode = 2 / ((third - first) / 1_000_000_000)
    return {
        "runIndex": run_index,
        "role": role,
        "outcome": "completed",
        "errorMessage": None,
        "promptTokenCount": 235,
        "outputTokenCount": 3,
        "stopReason": "endOfSequence",
        "thermalStateBefore": "nominal",
        "thermalStateAfter": "nominal",
        "memorySamplingIntervalMilliseconds": 50,
        "metrics": {
            "ttftMilliseconds": first / 1_000_000,
            "prefillTokensPerSecond": 470 / scale,
            "decodeTokensPerSecond": decode,
            "peakMemoryMegabytes": 720 * scale,
            "p50TokenIntervalMilliseconds": 20 * scale,
            "p95TokenIntervalMilliseconds": 20 * scale,
            "p99TokenIntervalMilliseconds": 20 * scale,
        },
        "tokenEvents": [
            {"index": 0, "tokenID": 10, "elapsedNanoseconds": first},
            {"index": 1, "tokenID": 11, "elapsedNanoseconds": second},
            {"index": 2, "tokenID": 12, "elapsedNanoseconds": third},
        ],
    }


def valid_bundle() -> dict:
    attempts = [attempt(0, "warmup")] + [
        attempt(index, "measured", 1 + (index - 1) * 0.01)
        for index in range(1, 6)
    ]
    measured = attempts[1:]

    def median(metric: str) -> float:
        values = sorted(value["metrics"][metric] for value in measured)
        return values[len(values) // 2]

    first, last = measured[0], measured[-1]

    def change(metric: str) -> float:
        return (last["metrics"][metric] / first["metrics"][metric] - 1) * 100

    return {
        "schemaVersion": "suite-b-pilot-bundle-0.3",
        "resultID": "fixture-result-id",
        "createdAt": "2026-07-10T13:01:48Z",
        "officialResultEligible": False,
        "plan": {
            "id": "suite-b-pilot-001",
            "version": "0.1.0",
            "promptSHA256": "a" * 64,
            "warmupRuns": 1,
            "measuredRuns": 5,
            "outputTokenLimit": 512,
        },
        "model": {},
        "runtime": {},
        "device": {},
        "eligibility": {
            "officialLeaderboard": {
                "eligible": False,
                "reasonCodes": ["pilot_protocol_not_official"],
            }
        },
        "summary": {
            "successfulMeasuredRuns": 5,
            "failedMeasuredRuns": 0,
            "medianTTFTMilliseconds": median("ttftMilliseconds"),
            "medianPrefillTokensPerSecond": median("prefillTokensPerSecond"),
            "medianDecodeTokensPerSecond": median("decodeTokensPerSecond"),
            "medianPeakMemoryMegabytes": median("peakMemoryMegabytes"),
            "finalThermalState": "nominal",
            "degradation": {
                "firstMeasuredRunIndex": 1,
                "lastMeasuredRunIndex": 5,
                "decodePercentChange": change("decodeTokensPerSecond"),
                "ttftPercentChange": change("ttftMilliseconds"),
                "prefillPercentChange": change("prefillTokensPerSecond"),
            },
        },
        "attempts": attempts,
    }


class WorkloadManifestTests(unittest.TestCase):
    def test_four_draft_workloads_have_distinct_ids(self) -> None:
        manifests = [json.loads(path.read_text()) for path in sorted(WORKLOADS.glob("*.json"))]
        self.assertEqual(len(manifests), 4)
        self.assertEqual(len({item["workload_id"] for item in manifests}), 4)
        self.assertEqual(
            {item["category"] for item in manifests},
            {"user-experience", "pipeline"},
        )
        self.assertTrue(all(not item["official_result_eligible"] for item in manifests))
        self.assertTrue(all(validate_workload(item) == [] for item in manifests))

    def test_pilot_mapping_is_pipeline_not_user_experience(self) -> None:
        manifest = json.loads(
            (WORKLOADS / "b-pipe-001-sustained-generation.json").read_text()
        )
        self.assertEqual(manifest["pilot_mapping"], "suite-b-pilot-001")
        self.assertEqual(manifest["category"], "pipeline")


class PilotBundleValidatorTests(unittest.TestCase):
    def test_valid_bundle_recalculates_cleanly(self) -> None:
        self.assertEqual(validate(valid_bundle()), [])

    def test_current_0_4_identity_and_power_fields_are_required(self) -> None:
        bundle = valid_bundle()
        bundle["schemaVersion"] = "suite-b-pilot-bundle-0.4"
        bundle["plan"]["v2ProfileMapping"] = (
            "b-pipe-001-sustained-generation@0.1.0-draft"
        )
        bundle["workload"] = {
            "id": "pilot",
            "version": "1.0",
            "category": "pipeline",
            "promptSHA256": "a" * 64,
        }
        bundle["measurementMode"] = {
            "id": "mode",
            "timingBoundaryVersion": "1",
            "pipelineTTFTStart": "prepared",
            "pipelineTTFTEnd": "raw-token",
            "userVisibleTTFTAvailable": False,
            "decodeFormula": "documented",
            "memoryMetric": "physical-footprint",
        }
        bundle["generationConfiguration"] = {
            "samplingEnabled": False,
            "temperature": 0,
            "topP": None,
            "topK": None,
            "seed": None,
            "repetitionPenalty": None,
            "thinkingMode": "model-default",
            "chatTemplateIdentity": "artifact",
            "outputTokenLimit": 512,
            "kvCachePolicy": "new",
        }
        bundle["model"] = {
            "baseModelID": "base",
            "artifactID": "artifact",
            "artifactRevision": "a" * 40,
            "quantization": "4-bit",
            "modelFormat": "MLX",
            "artifactContentHash": None,
        }
        bundle["runtime"] = {
            "name": "MLX Swift LM",
            "version": "3.31.4",
            "resolvedRevision": "b" * 40,
            "backend": "MLX/Metal",
            "mlxSwiftVersion": "0.31.6",
            "mlxSwiftRevision": "c" * 40,
            "downloaderPackage": "swift-huggingface 0.9.0",
            "tokenizerPackage": "swift-transformers 1.3.0",
        }
        bundle["device"] = {
            "appSourceCommit": None,
            "lowPowerModeEnabled": False,
            "batteryLevelPercent": 75,
            "batteryState": "unplugged",
        }
        self.assertEqual(validate(bundle), [])

        del bundle["generationConfiguration"]
        self.assertIn(
            "generationConfiguration must be an object",
            validate(bundle),
        )

    def test_official_flag_is_rejected(self) -> None:
        bundle = valid_bundle()
        bundle["officialResultEligible"] = True
        self.assertIn("pilot officialResultEligible must be false", validate(bundle))

    def test_non_contiguous_token_index_is_rejected(self) -> None:
        bundle = valid_bundle()
        bundle["attempts"][1]["tokenEvents"][1]["index"] = 9
        self.assertTrue(
            any("index must equal 1" in error for error in validate(bundle))
        )

    def test_summary_must_match_raw_attempts(self) -> None:
        bundle = valid_bundle()
        bundle["summary"]["medianDecodeTokensPerSecond"] = 999
        self.assertIn(
            "summary.medianDecodeTokensPerSecond does not match attempts",
            validate(bundle),
        )


if __name__ == "__main__":
    unittest.main()
