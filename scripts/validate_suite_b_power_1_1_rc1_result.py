#!/usr/bin/env python3
"""Validate Power 1.1 RC1 evidence and emit a hash-bound decision report."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts import validate_suite_b_power_result as power10  # noqa: E402


SUITE = ROOT / "benchmarks" / "suite-b-on-device-performance"
MANIFEST_PATH = SUITE / "releases" / "suite-b-power-1.1.0-rc.1.json"
RESULT_SCHEMA_PATH = ROOT / "schemas/suite-b-power-result-1.1.0-rc.1.schema.json"
BASE_RESULT_SCHEMA_PATH = ROOT / "schemas/suite-b-power-result-1.0.0-rc.1.schema.json"
REPORT_SCHEMA_PATH = ROOT / "schemas/suite-b-power-validation-report-1.1.0-rc.1.schema.json"
REASON_REGISTRY_PATH = SUITE / "power-1.1-rc1-validation-reasons.json"

PROTOCOL_VERSION = "1.1.0-rc.1"
RESULT_SCHEMA_VERSION = "suite-b-power-result-1.1.0-rc.1"
REPORT_SCHEMA_VERSION = "suite-b-power-validation-report-1.1.0-rc.1"
VALIDATOR_ID = "suite-b-power-validator"
VALIDATOR_VERSION = "1.1.0-rc.1"
RANKING_POLICY_ID = "suite-b-power-ranking-policy"
RANKING_POLICY_VERSION = "1.1.0-rc.1"

WORKLOADS = {
    "b-ux-001-short-interaction": {
        "version": PROTOCOL_VERSION,
        "category": "user-experience",
        "fixture": "69b3cd45fb67e1882dabdc082636298123e01081c097af65b3fd133b19ccbc84",
        "mode": "b-mode-warm-resident-ux-v1",
        "output_limit": 128,
        "primary_metric": "first_renderable_proxy_ttft_ms@1",
        "metrics": [
            "first_renderable_proxy_ttft_ms@1",
            "pipeline_ttft_ms@1",
            "request_completion_ms@1",
            "prefill_tokens_per_second@1",
            "decode_tokens_per_second@1",
            "process_physical_footprint_mib@1",
        ],
    },
    "b-pipe-001-sustained-generation": {
        "version": PROTOCOL_VERSION,
        "category": "pipeline",
        "fixture": "b865ad1a1993bfd7bf097b85f7c5585e44f1384fa291b9c05426c6051caba996",
        "mode": "b-mode-sustained-no-rest-v1",
        "output_limit": 512,
        "primary_metric": "decode_tokens_per_second@1",
        "metrics": [
            "pipeline_ttft_ms@1",
            "prefill_tokens_per_second@1",
            "decode_tokens_per_second@1",
            "process_physical_footprint_mib@1",
            "decode_first_to_last_percent_change@1",
        ],
    },
}

ATTEMPT_METRICS = power10.ATTEMPT_METRICS
SUMMARY_METRICS = power10.SUMMARY_METRICS
OUTCOMES = power10.OUTCOMES
STOPS = power10.STOPS
THERMAL = power10.THERMAL
ATTEMPT_REASON_CODES = power10.ATTEMPT_REASON_CODES


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256(path: Path) -> str:
    return _sha256_bytes(path.read_bytes())


def _unique(values: list[str]) -> list[str]:
    return list(dict.fromkeys(values))


def _asset_nodes(value: Any) -> list[dict[str, Any]]:
    if isinstance(value, dict):
        found = [value] if isinstance(value.get("path"), str) and isinstance(value.get("sha256"), str) else []
        return found + [node for child in value.values() for node in _asset_nodes(child)]
    if isinstance(value, list):
        return [node for child in value for node in _asset_nodes(child)]
    return []


def verify_rc_assets() -> list[str]:
    try:
        manifest = json.loads(MANIFEST_PATH.read_text())
    except (OSError, json.JSONDecodeError) as error:
        return [f"RC manifest unavailable: {error}"]
    errors: list[str] = []
    for asset in _asset_nodes(manifest):
        path = ROOT / asset["path"]
        if not path.is_file():
            errors.append(f"missing RC asset: {asset['path']}")
        elif _sha256(path) != asset["sha256"]:
            errors.append(f"RC asset digest mismatch: {asset['path']}")
    return errors


def _reference_app_identity() -> dict[str, str]:
    manifest = json.loads(MANIFEST_PATH.read_text())
    reference = manifest["referenceApp"]
    return {
        "runnerVersion": reference["version"],
        "appVersion": reference["version"],
        "appBuild": reference["build"],
        "appSourceCommit": reference["sourceCommit"],
    }


def _resolve_pointer(document: Any, fragment: str) -> Any:
    if fragment in {"", "#"}:
        return document
    if not fragment.startswith("#/"):
        raise ValueError(f"unsupported schema fragment: {fragment}")
    node = document
    for raw_part in fragment[2:].split("/"):
        part = raw_part.replace("~1", "/").replace("~0", "~")
        node = node[int(part)] if isinstance(node, list) else node[part]
    return node


def _resolve_registry_ref(
    current_root: dict[str, Any],
    reference: str,
    registry: dict[str, dict[str, Any]],
) -> tuple[dict[str, Any], dict[str, Any]]:
    if reference.startswith("#"):
        target_root = current_root
        fragment = reference
    else:
        schema_id, separator, suffix = reference.partition("#")
        if schema_id not in registry:
            raise ValueError(f"unregistered schema reference: {schema_id}")
        target_root = registry[schema_id]
        fragment = f"#{suffix}" if separator else "#"
    target = _resolve_pointer(target_root, fragment)
    if not isinstance(target, dict):
        raise ValueError(f"schema reference is not an object: {reference}")
    return target, target_root


def _validate_schema(
    value: Any,
    schema: dict[str, Any],
    root: dict[str, Any],
    registry: dict[str, dict[str, Any]],
    path: str = "$",
) -> list[str]:
    if "$ref" in schema:
        try:
            target, target_root = _resolve_registry_ref(root, schema["$ref"], registry)
        except (KeyError, IndexError, TypeError, ValueError) as error:
            return [f"{path} has an unresolved schema reference: {error}"]
        return _validate_schema(value, target, target_root, registry, path)

    errors: list[str] = []
    if "const" in schema and not power10._json_equal(value, schema["const"]):
        errors.append(f"{path} must equal the frozen constant")
    if "enum" in schema and not any(
        power10._json_equal(value, option) for option in schema["enum"]
    ):
        errors.append(f"{path} is outside the frozen enum")
    expected_type = schema.get("type")
    if expected_type is not None:
        choices = expected_type if isinstance(expected_type, list) else [expected_type]
        if not any(power10._matches_type(value, choice) for choice in choices):
            errors.append(f"{path} has the wrong JSON type")
            return errors

    if isinstance(value, dict):
        properties = schema.get("properties", {})
        for required in schema.get("required", []):
            if required not in value:
                errors.append(f"{path}.{required} is required")
        property_names = schema.get("propertyNames")
        additional = schema.get("additionalProperties", True)
        for key, child in value.items():
            child_path = f"{path}.{key}"
            if isinstance(property_names, dict):
                errors.extend(
                    _validate_schema(key, property_names, root, registry, child_path)
                )
            if key in properties:
                errors.extend(
                    _validate_schema(child, properties[key], root, registry, child_path)
                )
            elif additional is False:
                errors.append(f"{child_path} is not allowed")
            elif isinstance(additional, dict):
                errors.extend(
                    _validate_schema(child, additional, root, registry, child_path)
                )
        if len(value) < schema.get("minProperties", 0):
            errors.append(f"{path} has too few properties")

    if isinstance(value, list):
        if len(value) < schema.get("minItems", 0):
            errors.append(f"{path} has too few items")
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            errors.append(f"{path} has too many items")
        if schema.get("uniqueItems") and len(
            {json.dumps(item, sort_keys=True) for item in value}
        ) != len(value):
            errors.append(f"{path} must contain unique items")
        item_schema = schema.get("items")
        if isinstance(item_schema, dict):
            for index, child in enumerate(value):
                errors.extend(
                    _validate_schema(
                        child, item_schema, root, registry, f"{path}[{index}]"
                    )
                )

    if isinstance(value, str):
        if len(value) < schema.get("minLength", 0):
            errors.append(f"{path} is too short")
        if "pattern" in schema and re.search(schema["pattern"], value) is None:
            errors.append(f"{path} does not match the required pattern")
        if schema.get("format") == "date-time":
            try:
                datetime.fromisoformat(value.replace("Z", "+00:00"))
            except ValueError:
                errors.append(f"{path} is not a date-time")
        if schema.get("format") == "uri" and not urlparse(value).scheme:
            errors.append(f"{path} is not a URI")

    if power10._finite_number(value):
        if "minimum" in schema and value < schema["minimum"]:
            errors.append(f"{path} is below the minimum")
        if "maximum" in schema and value > schema["maximum"]:
            errors.append(f"{path} is above the maximum")
        if "exclusiveMinimum" in schema and value <= schema["exclusiveMinimum"]:
            errors.append(f"{path} must be greater than the exclusive minimum")

    for child_schema in schema.get("allOf", []):
        errors.extend(_validate_schema(value, child_schema, root, registry, path))
    condition = schema.get("if")
    if isinstance(condition, dict):
        condition_errors = _validate_schema(value, condition, root, registry, path)
        branch = schema.get("then") if not condition_errors else schema.get("else")
        if isinstance(branch, dict):
            errors.extend(_validate_schema(value, branch, root, registry, path))
    return errors


def _load_schema_registry(*paths: Path) -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]]]:
    schemas = [json.loads(path.read_text()) for path in paths]
    registry = {
        schema["$id"]: schema
        for schema in schemas
        if isinstance(schema.get("$id"), str)
    }
    return schemas, registry


def _shape_errors(data: Any) -> list[str]:
    try:
        schemas, registry = _load_schema_registry(
            RESULT_SCHEMA_PATH, BASE_RESULT_SCHEMA_PATH
        )
    except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        return [f"frozen result schema is unavailable: {error}"]
    return _unique(_validate_schema(data, schemas[0], schemas[0], registry))


def validate_report_shape(report: Any) -> list[str]:
    try:
        schemas, registry = _load_schema_registry(REPORT_SCHEMA_PATH)
        schema = schemas[0]
    except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        return [f"validation-report schema unavailable: {error}"]
    errors = _validate_schema(report, schema, schema, registry)
    if not isinstance(report, dict):
        return _unique(errors)
    try:
        registry = set(json.loads(REASON_REGISTRY_PATH.read_text())["reason_codes"])
    except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        errors.append(f"validation-reason registry unavailable: {error}")
    else:
        unregistered = _report_reason_codes(report) - registry
        if unregistered:
            errors.append(
                "$.reasonCodes contains unregistered values: "
                + ", ".join(sorted(unregistered))
            )
    return _unique(errors)


def _report_reason_codes(value: Any) -> set[str]:
    if isinstance(value, dict):
        found = {
            reason
            for reason in value.get("reasonCodes", [])
            if isinstance(reason, str)
        }
        return found.union(*(_report_reason_codes(child) for child in value.values()))
    if isinstance(value, list):
        return set().union(*(_report_reason_codes(child) for child in value))
    return set()


def _validity(valid: bool, reasons: list[str]) -> dict[str, Any]:
    return {"valid": valid, "reasonCodes": _unique(reasons)}


def _eligibility(eligible: bool, reasons: list[str]) -> dict[str, Any]:
    return {"eligible": eligible, "reasonCodes": _unique(reasons)}


def _result_reference(data: Any, result_sha256: str) -> dict[str, Any]:
    result_id = data.get("resultID") if isinstance(data, dict) else None
    schema_version = data.get("schemaVersion") if isinstance(data, dict) else None
    return {
        "id": result_id if isinstance(result_id, str) and result_id else None,
        "sha256": result_sha256,
        "schemaVersion": schema_version if isinstance(schema_version, str) and schema_version else "unknown",
    }


def _base_report(data: Any, result_sha256: str) -> dict[str, Any]:
    return {
        "schemaVersion": REPORT_SCHEMA_VERSION,
        "result": _result_reference(data, result_sha256),
        "benchmarkRelease": {
            "id": "suite-b-power",
            "protocolVersion": PROTOCOL_VERSION,
        },
        "validator": {"id": VALIDATOR_ID, "version": VALIDATOR_VERSION},
        "rankingPolicy": {
            "id": RANKING_POLICY_ID,
            "version": RANKING_POLICY_VERSION,
        },
        "structuralValidity": _validity(False, ["schema_invalid"]),
        "protocolConformance": _validity(False, ["schema_invalid"]),
        "metricEligibility": {},
        "behaviorConformance": {
            "applicable": False,
            "policyID": None,
            "status": None,
            "reasonCodes": [],
        },
        "performanceRankingEligibility": _eligibility(
            False, ["release_candidate_not_rank_authorized"]
        ),
        "recommendationEligibility": _eligibility(
            False, ["release_candidate_not_rank_authorized"]
        ),
    }


def _add_error(
    errors: list[str], reasons: list[str], message: str, reason: str
) -> None:
    errors.append(message)
    reasons.append(reason)


def _attempt_values(
    attempt: dict[str, Any],
    workload_id: str,
    errors: list[str],
    reasons: list[str],
    label: str,
) -> dict[str, float | None]:
    values = {metric: None for metric in ATTEMPT_METRICS}
    if attempt.get("outcome") != "completed":
        outcome = attempt.get("outcome")
        attempt_reasons = attempt.get("reasonCodes", [])
        if (
            attempt.get("stopReason") is not None
            or not attempt_reasons
            or any(
                reason not in ATTEMPT_REASON_CODES.get(outcome, set())
                for reason in attempt_reasons
            )
        ):
            _add_error(
                errors,
                reasons,
                f"{label}: non-completed outcome has contradictory evidence",
                "contradictory_outcome_evidence",
            )
        if any(value is not None for value in attempt.get("derivedMetrics", {}).values()):
            _add_error(
                errors,
                reasons,
                f"{label}: non-completed attempt metrics must be null",
                "aggregate_mismatch",
            )
        if attempt.get("outcome") == "notRun" and any(
            (attempt.get("tokenEvents"), attempt.get("memorySamples"))
        ):
            _add_error(
                errors,
                reasons,
                f"{label}: notRun attempt cannot contain measurement events",
                "contradictory_outcome_evidence",
            )
        return values

    if attempt.get("stopReason") not in STOPS or attempt.get("reasonCodes"):
        _add_error(
            errors,
            reasons,
            f"{label}: completed outcome has contradictory stop/reason evidence",
            "contradictory_outcome_evidence",
        )
    tokens = attempt.get("tokenEvents", [])
    output_count = attempt.get("outputTokenCount")
    prompt_count = attempt.get("promptTokenCount")
    output_limit = WORKLOADS[workload_id]["output_limit"]
    if not isinstance(output_count, int) or not 0 <= output_count <= output_limit:
        _add_error(
            errors,
            reasons,
            f"{label}: output token count is outside the workload limit",
            "token_evidence_invalid",
        )
    if attempt.get("stopReason") == "outputTokenLimit" and output_count != output_limit:
        _add_error(
            errors,
            reasons,
            f"{label}: outputTokenLimit stop requires the exact workload limit",
            "contradictory_outcome_evidence",
        )
    if workload_id == "b-ux-001-short-interaction" and not (
        isinstance(prompt_count, int) and 64 <= prompt_count <= 256
    ):
        _add_error(
            errors,
            reasons,
            f"{label}: Short Interaction prompt token count is outside 64...256",
            "token_evidence_invalid",
        )

    valid_tokens = isinstance(output_count, int) and output_count == len(tokens)
    previous = -1
    for position, token in enumerate(tokens):
        elapsed = token.get("elapsedNanoseconds") if isinstance(token, dict) else None
        if (
            not isinstance(token, dict)
            or token.get("index") != position
            or not isinstance(token.get("tokenID"), int)
            or not isinstance(elapsed, int)
            or elapsed < previous
        ):
            valid_tokens = False
            break
        previous = elapsed
    if not valid_tokens:
        _add_error(
            errors,
            reasons,
            f"{label}: token evidence is invalid",
            "token_evidence_invalid",
        )
    if valid_tokens and tokens:
        values["pipeline_ttft_ms@1"] = tokens[0]["elapsedNanoseconds"] / 1_000_000

    timing = attempt.get("timingEvidence", {})
    prompt_ns = timing.get("promptEvaluationNanoseconds")
    if (
        isinstance(prompt_count, int)
        and prompt_count > 0
        and isinstance(prompt_ns, int)
        and prompt_ns > 0
    ):
        values["prefill_tokens_per_second@1"] = (
            prompt_count * 1_000_000_000 / prompt_ns
        )
    if valid_tokens and len(tokens) >= 2:
        interval = tokens[-1]["elapsedNanoseconds"] - tokens[0]["elapsedNanoseconds"]
        if interval > 0:
            values["decode_tokens_per_second@1"] = (
                (len(tokens) - 1) * 1_000_000_000 / interval
            )

    samples = attempt.get("memorySamples", [])
    valid_samples = bool(samples)
    previous = -1
    footprints: list[int] = []
    for sample in samples:
        elapsed = sample.get("elapsedNanoseconds") if isinstance(sample, dict) else None
        footprint = sample.get("physicalFootprintBytes") if isinstance(sample, dict) else None
        if (
            not isinstance(elapsed, int)
            or elapsed < previous
            or not isinstance(footprint, int)
            or footprint <= 0
        ):
            valid_samples = False
            break
        previous = elapsed
        footprints.append(footprint)
    if valid_samples:
        values["process_physical_footprint_mib@1"] = max(footprints) / 1_048_576

    if workload_id == "b-ux-001-short-interaction":
        trace_errors: list[str] = []
        values["first_renderable_proxy_ttft_ms@1"] = power10._trace_value(
            attempt, trace_errors, label
        )
        for message in trace_errors:
            _add_error(
                errors,
                reasons,
                message,
                "first_renderable_evidence_invalid",
            )
        completion = timing.get("requestCompletionNanoseconds")
        if isinstance(completion, int) and completion > 0:
            last_token_request_time = timing.get("generationStartNanoseconds", 0) + (
                tokens[-1]["elapsedNanoseconds"] if tokens else 0
            )
            if completion < last_token_request_time:
                _add_error(
                    errors,
                    reasons,
                    f"{label}: request completion precedes the final token",
                    "contradictory_outcome_evidence",
                )
            else:
                values["request_completion_ms@1"] = completion / 1_000_000
    return values


def _behavior_assessment(
    workload_id: str, attempts: list[dict[str, Any]]
) -> dict[str, Any]:
    if workload_id != "b-ux-001-short-interaction":
        return {
            "applicable": False,
            "policyID": None,
            "status": None,
            "reasonCodes": [],
        }
    verified = sum(
        attempt.get("outcome") == "completed"
        and power10._response_conformant(attempt.get("generatedText"))
        for attempt in attempts[1:]
    )
    status = "verified" if verified >= 3 else "not_verified"
    return {
        "applicable": True,
        "policyID": "short-interaction-response-v1",
        "status": status,
        "reasonCodes": [] if status == "verified" else ["behavior_not_verified"],
    }


def validate(data: Any, result_sha256: str) -> dict[str, Any]:
    report = _base_report(data, result_sha256)
    structural_errors = _shape_errors(data)
    if structural_errors:
        return report
    report["structuralValidity"] = _validity(True, [])

    asset_errors = verify_rc_assets()
    if asset_errors:
        report["protocolConformance"] = _validity(
            False, ["release_asset_mismatch"]
        )
        return report

    errors: list[str] = []
    conformance_reasons: list[str] = []
    execution = data["execution"]
    workload_id = execution["workloadID"]
    workload = WORKLOADS.get(workload_id)
    if workload is None:
        report["protocolConformance"] = _validity(
            False, ["workload_identity_mismatch"]
        )
        return report

    expected_execution = {
        "workloadVersion": workload["version"],
        "workloadCategory": workload["category"],
        "fixtureSHA256": workload["fixture"],
        "measurementModeID": workload["mode"],
    }
    for field, expected in expected_execution.items():
        if execution.get(field) != expected:
            _add_error(
                errors,
                conformance_reasons,
                f"execution.{field} does not match the frozen RC protocol",
                "fixture_hash_mismatch" if field == "fixtureSHA256" else "workload_identity_mismatch",
            )
    try:
        reference_app = _reference_app_identity()
    except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        _add_error(
            errors,
            conformance_reasons,
            f"reference App identity is unavailable: {error}",
            "release_asset_mismatch",
        )
    else:
        for field, expected in reference_app.items():
            if execution.get(field) != expected:
                _add_error(
                    errors,
                    conformance_reasons,
                    f"execution.{field} does not match the frozen reference App",
                    "runner_incompatible",
                )

    config = data["configuration"]
    expected_config = {
        "warmupAttempts": 1,
        "measuredAttempts": 5,
        "minimumMetricEligibleMeasuredAttempts": 3,
        "restIntervalSeconds": 0,
        "samplingEnabled": False,
        "temperature": 0,
        "includeStopTokenInRawEvents": False,
        "outputTokenLimit": workload["output_limit"],
        "modelLoadPolicy": "load-once-before-warmup",
        "contextPolicy": "fresh-conversation-per-attempt",
        "kvCachePolicy": "fresh-kv-cache-per-attempt",
        "automaticRetries": 0,
        "clock": "monotonic-nanoseconds",
        "memorySamplingIntervalMilliseconds": 50,
        "memoryMetric": "TASK_VM_INFO.phys_footprint",
        "thermalSource": "ProcessInfo.thermalState",
    }
    expected_config.update(
        {
            "topP": 1,
            "topK": 0,
            "seed": 0,
            "repetitionPenalty": None,
            "thinkingMode": "disabled-via-chat-template",
            "chatTemplateIdentity": "artifact-tokenizer-config-enable-thinking-false",
        }
        if workload_id == "b-ux-001-short-interaction"
        else {
            "topP": None,
            "topK": None,
            "seed": None,
            "repetitionPenalty": None,
            "thinkingMode": "disabled-via-prompt-directive",
            "chatTemplateIdentity": "artifact-tokenizer-config",
        }
    )
    for field, expected in expected_config.items():
        if config.get(field) != expected:
            _add_error(
                errors,
                conformance_reasons,
                f"configuration.{field} does not match the frozen RC protocol",
                "release_identity_mismatch",
            )

    environment = data["environment"]
    if not (
        environment.get("buildConfiguration") == "Release"
        and environment.get("debuggerAttached") is False
        and environment.get("lowPowerModeEnabled") is False
        and environment.get("batteryState") == "unplugged"
        and power10._finite_number(environment.get("batteryLevelPercentAtStart"))
        and environment["batteryLevelPercentAtStart"] >= 50
        and environment.get("thermalStateAtSessionStart") == "nominal"
    ):
        _add_error(
            errors,
            conformance_reasons,
            "environment admission requirements failed",
            "environment_ineligible",
        )

    preparation = data["modelPreparation"]
    if not (
        preparation.get("artifactID") == data["model"].get("artifactID")
        and preparation.get("artifactRevision") == data["model"].get("artifactRevision")
        and preparation.get("downloadOccurredDuringSession") is False
        and preparation.get("preparationCompleted") is True
        and preparation.get("modelLoadCompleted") is True
        and preparation.get("eligibleForPerformanceMeasurement") is True
    ):
        _add_error(
            errors,
            conformance_reasons,
            "model preparation does not satisfy the frozen RC protocol",
            "model_preparation_ineligible",
        )

    attempts = data["attempts"]
    attempt_values: list[dict[str, float | None]] = []
    stopped_for_critical = False
    for position, attempt in enumerate(attempts):
        expected_role = "warmup" if position == 0 else "measured"
        if attempt.get("runIndex") != position or attempt.get("role") != expected_role:
            _add_error(
                errors,
                conformance_reasons,
                f"attempts[{position}] has invalid index/role sequence",
                "attempt_sequence_invalid",
            )
        thermal = attempt.get("thermal", {})
        if thermal.get("before") not in THERMAL or thermal.get("after") not in THERMAL:
            _add_error(
                errors,
                conformance_reasons,
                f"attempts[{position}] has invalid thermal evidence",
                "thermal_evidence_unavailable",
            )
        if thermal.get("before") == "critical":
            stopped_for_critical = True
        if stopped_for_critical and (
            attempt.get("outcome") != "notRun"
            or "thermal_state_critical_before_attempt" not in attempt.get("reasonCodes", [])
        ):
            _add_error(
                errors,
                conformance_reasons,
                f"attempts[{position}] contradicts the critical-thermal stop",
                "contradictory_outcome_evidence",
            )
        values = _attempt_values(
            attempt,
            workload_id,
            errors,
            conformance_reasons,
            f"attempts[{position}]",
        )
        attempt_values.append(values)
        for metric, field in ATTEMPT_METRICS.items():
            if not power10._close(attempt["derivedMetrics"].get(field), values[metric]):
                _add_error(
                    errors,
                    conformance_reasons,
                    f"attempts[{position}].derivedMetrics.{field} mismatch",
                    "aggregate_mismatch",
                )

    measured_pairs = list(zip(attempts[1:], attempt_values[1:]))
    metric_decisions: dict[str, dict[str, Any]] = {}
    global_metric_reasons = _unique(
        [
            reason
            for reason in conformance_reasons
            if reason
            in {
                "release_identity_mismatch",
                "workload_identity_mismatch",
                "fixture_hash_mismatch",
                "runner_incompatible",
                "environment_ineligible",
                "model_preparation_ineligible",
            }
        ]
    )
    for metric, field in SUMMARY_METRICS.items():
        if metric in workload["metrics"] and global_metric_reasons:
            expected = None
            count = 0
            metric_reasons = global_metric_reasons
        elif metric == "decode_first_to_last_percent_change@1":
            if workload_id != "b-pipe-001-sustained-generation":
                expected = None
                count = 0
                metric_reasons = ["metric_not_applicable"]
            else:
                first = attempt_values[1]["decode_tokens_per_second@1"]
                last = attempt_values[5]["decode_tokens_per_second@1"]
                expected = ((last / first) - 1) * 100 if first and last else None
                count = 2 if expected is not None else 0
                metric_reasons = (
                    [] if expected is not None else ["insufficient_metric_eligible_attempts"]
                )
        elif metric not in workload["metrics"]:
            expected = None
            count = 0
            metric_reasons = ["metric_not_applicable"]
        else:
            values = [
                values[metric]
                for attempt, values in measured_pairs
                if attempt.get("outcome") == "completed" and values[metric] is not None
            ]
            count = len(values)
            expected = power10._median(values)
            metric_reasons = (
                [] if expected is not None else ["insufficient_metric_eligible_attempts"]
            )
        if metric in workload["metrics"]:
            metric_decisions[metric] = {
                "eligible": expected is not None,
                "eligibleMeasuredAttempts": count,
                "reasonCodes": metric_reasons,
            }
        if not power10._close(data["summary"]["metrics"].get(field), expected):
            _add_error(
                errors,
                conformance_reasons,
                f"summary.metrics.{field} mismatch",
                "aggregate_mismatch",
            )

    measured = attempts[1:]
    expected_counts = {
        outcome: sum(attempt.get("outcome") == outcome for attempt in measured)
        for outcome in OUTCOMES
    }
    expected_counts["earlyEOS"] = sum(
        attempt.get("outcome") == "completed"
        and attempt.get("stopReason") == "endOfSequence"
        for attempt in measured
    )
    if data["summary"].get("terminalCounts") != expected_counts:
        _add_error(
            errors,
            conformance_reasons,
            "summary.terminalCounts mismatch",
            "aggregate_mismatch",
        )

    protocol_valid = not errors
    report["protocolConformance"] = _validity(
        protocol_valid, [] if protocol_valid else conformance_reasons
    )
    report["metricEligibility"] = metric_decisions
    behavior = _behavior_assessment(workload_id, attempts)
    report["behaviorConformance"] = behavior

    primary = metric_decisions.get(workload["primary_metric"], {})
    ranking_reasons = ["release_candidate_not_rank_authorized"]
    if not primary.get("eligible"):
        ranking_reasons.append("primary_metric_ineligible")
    ranking_reasons.extend([] if protocol_valid else conformance_reasons)
    report["performanceRankingEligibility"] = _eligibility(False, ranking_reasons)

    recommendation_reasons = list(ranking_reasons)
    if behavior["applicable"] and behavior["status"] != "verified":
        recommendation_reasons.append("behavior_verification_required")
    report["recommendationEligibility"] = _eligibility(
        False, recommendation_reasons
    )
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("result", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    try:
        raw = args.result.read_bytes()
        data = json.loads(raw)
    except (OSError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    report = validate(data, _sha256_bytes(raw))
    shape_errors = validate_report_shape(report)
    if shape_errors:
        print(
            "internal validation-report error: " + "; ".join(shape_errors),
            file=sys.stderr,
        )
        return 2
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    try:
        if args.output:
            args.output.write_text(rendered)
        else:
            print(rendered, end="")
    except OSError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    return 0 if (
        report["structuralValidity"]["valid"]
        and report["protocolConformance"]["valid"]
    ) else 1


if __name__ == "__main__":
    raise SystemExit(main())
