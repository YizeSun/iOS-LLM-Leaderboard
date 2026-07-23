"""Derive Power 2 ranking views from accepted two-file packages."""

from __future__ import annotations

import hashlib
import json
import statistics
from collections import defaultdict
from pathlib import Path
from typing import Any

from .engine import ValidationContext, load_candidate_context, validate_package


def _canonical_sha256(value: Any) -> str:
    encoded = json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _comparison_identity(result: dict[str, Any]) -> dict[str, Any]:
    payload = result["payload"]
    workload = payload["workload"]
    model = result["model"]
    device = result["device"]
    return {
        "programID": result["program"]["id"],
        "programVersion": result["program"]["version"],
        "targetID": result["target"]["id"],
        "targetVersion": result["target"]["version"],
        "runnerCertificateID": result["runnerCertificateID"],
        "workloadID": workload["id"],
        "workloadVersion": workload["version"],
        "measurementMode": payload["measurementMode"],
        "modelArtifactID": model["artifactID"],
        "modelArtifactRevision": model["artifactRevision"],
        "quantization": model["quantization"],
        "runtimeIdentity": result["runtime"],
        "machineIdentifier": device["machineIdentifier"],
        "osVersion": device["osVersion"],
        "osBuild": device["osBuild"],
        "inferenceConfiguration": payload["inferenceConfiguration"],
    }


def _attempt_metric(
    attempt: dict[str, Any],
    metric_id: str,
) -> float | None:
    monotonic = attempt.get("monotonic", {})
    counts = attempt.get("tokenCounts", {})
    memory = attempt.get("memory", {})
    accepted = monotonic.get("requestAcceptedNanoseconds")
    if not isinstance(accepted, int):
        return None
    if metric_id == "first_renderable_ms":
        value = monotonic.get("firstRenderableNanoseconds")
        return (
            (value - accepted) / 1_000_000
            if isinstance(value, int)
            else None
        )
    if metric_id == "pipeline_ttft_ms":
        value = monotonic.get("firstTokenNanoseconds")
        return (
            (value - accepted) / 1_000_000
            if isinstance(value, int)
            else None
        )
    if metric_id == "request_completion_ms":
        value = monotonic.get("completedNanoseconds")
        return (
            (value - accepted) / 1_000_000
            if isinstance(value, int)
            else None
        )
    if metric_id == "prefill_tokens_per_second":
        duration = monotonic.get("promptEvaluationNanoseconds")
        tokens = counts.get("input")
        return (
            tokens / (duration / 1_000_000_000)
            if isinstance(duration, int)
            and duration > 0
            and isinstance(tokens, int)
            and tokens > 0
            else None
        )
    if metric_id == "decode_tokens_per_second":
        duration = monotonic.get("decodeNanoseconds")
        tokens = counts.get("output")
        return (
            (tokens - 1) / (duration / 1_000_000_000)
            if isinstance(duration, int)
            and duration > 0
            and isinstance(tokens, int)
            and tokens >= 2
            else None
        )
    if metric_id == "peak_physical_footprint_mib":
        value = memory.get("peakPhysicalFootprintBytes")
        return (
            value / 1_048_576
            if isinstance(value, int)
            else None
        )
    return None


def _result_metric(
    result: dict[str, Any],
    metric: dict[str, Any],
) -> float | None:
    metric_id = metric["id"]
    attempts = [
        attempt
        for attempt in result["payload"]["attempts"]
        if attempt.get("phase") == "measured"
        and attempt.get("outcome") == "succeeded"
    ]
    if metric_id == "decode_first_to_last_percent_change":
        values = [
            _attempt_metric(attempt, "decode_tokens_per_second")
            for attempt in attempts
        ]
        eligible = [value for value in values if value is not None]
        if len(eligible) < 2 or eligible[0] == 0:
            return None
        return (eligible[-1] - eligible[0]) / eligible[0] * 100

    values = [
        value
        for value in (
            _attempt_metric(attempt, metric_id)
            for attempt in attempts
        )
        if value is not None
    ]
    if not values:
        return None
    if metric.get("aggregation") == "maximum":
        return max(values)
    return statistics.median(values)


def build_dataset(
    submissions_root: Path,
    *,
    context: ValidationContext | None = None,
    generated_at: str,
    validator_source_revision: str,
) -> dict[str, Any]:
    context = context or load_candidate_context()
    ranking_policy = context.policy_documents["ranking"]
    thresholds = ranking_policy["distinctContributorThresholds"]
    metrics = {
        metric["id"]: metric
        for metric in context.program_contract["metrics"]
    }
    accepted_digests: set[str] = set()
    contributions: list[dict[str, Any]] = []
    excluded: list[dict[str, Any]] = []

    package_paths = sorted(
        path
        for path in Path(submissions_root).iterdir()
        if path.is_dir()
    ) if Path(submissions_root).is_dir() else []
    for package in package_paths:
        submission = json.loads(
            (package / "submission.json").read_text(encoding="utf-8")
        )
        contributor = submission["contributor"]["githubLogin"]
        report = validate_package(
            package,
            context=context,
            evaluated_at=generated_at,
            validator_source_revision=validator_source_revision,
            pr_author=contributor,
            accepted_result_digests=accepted_digests,
        )
        digest = report["sourceResultSHA256"]
        accepted_digests.add(digest)
        if report["classification"] != "auto-accept":
            excluded.append(
                {
                    "submissionID": submission["submissionID"],
                    "sourceResultSHA256": digest,
                    "classification": report["classification"],
                    "reasonCodes": report["reasonCodes"],
                }
            )
            continue
        result = json.loads(
            (package / "result.json").read_text(encoding="utf-8")
        )
        identity = _comparison_identity(result)
        metric_values: dict[str, float] = {}
        for metric_id, decision in report["checks"][
            "metricEligibility"
        ].items():
            if decision["status"] != "pass":
                continue
            value = _result_metric(result, metrics[metric_id])
            if value is not None:
                metric_values[metric_id] = value
        contributions.append(
            {
                "submissionID": submission["submissionID"],
                "sourceResultSHA256": digest,
                "resultID": result["resultID"],
                "contributor": contributor,
                "contributorKey": contributor.casefold(),
                "comparisonID": _canonical_sha256(identity),
                "comparisonIdentity": identity,
                "metricValues": metric_values,
                "behaviorConformance": report["checks"][
                    "behaviorConformance"
                ],
                "recommendationEligibility": report["checks"][
                    "recommendationEligibility"
                ],
            }
        )

    grouped: dict[
        tuple[str, str],
        list[dict[str, Any]],
    ] = defaultdict(list)
    for contribution in contributions:
        for metric_id in contribution["metricValues"]:
            grouped[(contribution["comparisonID"], metric_id)].append(
                contribution
            )

    views: list[dict[str, Any]] = []
    view_definitions = {
        view["workloadID"]: view
        for view in ranking_policy["views"]
    }
    for (comparison_id, metric_id), rows in grouped.items():
        identity = rows[0]["comparisonIdentity"]
        view = view_definitions.get(identity["workloadID"])
        if view is None or view["primaryMetric"] != metric_id:
            continue
        by_contributor: dict[str, list[float]] = defaultdict(list)
        for row in rows:
            by_contributor[row["contributorKey"]].append(
                row["metricValues"][metric_id]
            )
        contributor_values = {
            contributor: statistics.median(values)
            for contributor, values in by_contributor.items()
        }
        contributor_count = len(contributor_values)
        if contributor_count >= thresholds[
            "contributorWeightedAggregation"
        ]:
            state = "contributor-weighted"
        elif contributor_count >= thresholds["reproduced"]:
            state = "reproduced"
        else:
            state = "accepted"
        views.append(
            {
                "viewID": view["id"],
                "comparisonID": comparison_id,
                "comparisonIdentity": identity,
                "metricID": metric_id,
                "value": statistics.median(
                    contributor_values.values()
                ),
                "contributorCount": contributor_count,
                "submissionCount": len(rows),
                "evidenceState": state,
                "sourceResultSHA256s": sorted(
                    row["sourceResultSHA256"] for row in rows
                ),
            }
        )

    directions = {
        metric_id: metric["direction"]
        for metric_id, metric in metrics.items()
    }
    views.sort(
        key=lambda row: (
            row["viewID"],
            row["value"]
            if directions[row["metricID"]] == "lower-is-better"
            else -row["value"],
            row["comparisonID"],
        )
    )
    return {
        "schemaVersion": "power-ranking-dataset-1.0.0-draft.1",
        "generatedAt": generated_at,
        "validatorSourceRevision": validator_source_revision,
        "rankingPolicy": {
            "id": ranking_policy["policyID"],
            "version": ranking_policy["policyVersion"],
            "sha256": context.policy_references["ranking"]["sha256"],
        },
        "acceptedContributionCount": len(contributions),
        "excludedContributionCount": len(excluded),
        "views": views,
        "excluded": excluded,
    }


def write_dataset(
    submissions_root: Path,
    output_path: Path,
    *,
    context: ValidationContext | None = None,
    generated_at: str,
    validator_source_revision: str,
) -> dict[str, Any]:
    dataset = build_dataset(
        submissions_root,
        context=context,
        generated_at=generated_at,
        validator_source_revision=validator_source_revision,
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(dataset, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return dataset
