#!/usr/bin/env python3
"""Review one closed Power 2 Certification result without publishing it."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import tempfile
from pathlib import Path
from typing import Any

try:
    from scripts.lib.power2.engine import (
        Power2ValidationError,
        VALIDATOR_NAME,
        VALIDATOR_VERSION,
        load_candidate_certification_review_context,
        validate_package,
    )
except ModuleNotFoundError:
    from lib.power2.engine import (
        Power2ValidationError,
        VALIDATOR_NAME,
        VALIDATOR_VERSION,
        load_candidate_certification_review_context,
        validate_package,
    )


REVIEW_LOGIN = "power-certification-review"


def review_result(
    result_path: Path,
    *,
    evaluated_at: str,
    validator_source_revision: str,
) -> dict[str, Any]:
    result_path = Path(result_path)
    result_bytes = result_path.read_bytes()
    try:
        result = json.loads(result_bytes)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError(f"Certification result is not valid JSON: {error}") from error
    if not isinstance(result, dict):
        raise ValueError("Certification result must be a JSON object")
    result_id = result.get("resultID")
    created_at = result.get("createdAt")
    if not isinstance(result_id, str) or not isinstance(created_at, str):
        raise ValueError("Certification result has no result ID or timestamp")

    submission = {
        "schemaVersion": "power-submission-1.0.0-draft.1",
        "submissionID": result_id,
        "createdAt": created_at,
        "contributor": {
            "githubLogin": REVIEW_LOGIN,
            "conflictOfInterest": "none",
        },
        "sourceResult": {
            "path": "result.json",
            "sha256": hashlib.sha256(result_bytes).hexdigest(),
            "schemaVersion": result.get("schemaVersion"),
        },
        "declarations": {
            "physicalDevice": True,
            "publicMetadataReviewed": True,
            "rawEvidenceUnmodified": True,
            "containsNoPersonalData": True,
            "licenseAccepted": "CC-BY-4.0",
            "rankingNotGuaranteed": True,
        },
    }

    with tempfile.TemporaryDirectory() as temporary:
        package = Path(temporary) / result_id
        package.mkdir()
        (package / "result.json").write_bytes(result_bytes)
        (package / "submission.json").write_text(
            json.dumps(submission, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        report = validate_package(
            package,
            context=load_candidate_certification_review_context(),
            evaluated_at=evaluated_at,
            validator_source_revision=validator_source_revision,
            pr_author=REVIEW_LOGIN,
        )

    passing = report.get("classification") == "auto-accept"
    return {
        "schemaVersion":
            "power-runner-certification-review-1.0.0-draft.1",
        "reviewedAt": evaluated_at,
        "validator": {
            "name": VALIDATOR_NAME,
            "version": VALIDATOR_VERSION,
            "sourceRevision": validator_source_revision,
        },
        "status": "pass" if passing else "fail",
        "physicalDeviceSmokeRun": "pass" if passing else "fail",
        "rawResultReview": "pass" if passing else "fail",
        "publishable": False,
        "rankingEligible": False,
        "sourceResultSHA256": report.get("sourceResultSHA256"),
        "runnerCertificateID": result.get("runnerCertificateID"),
        "appRelease": result.get("appRelease"),
        "checks": report.get("checks"),
        "reasonCodes": report.get("reasonCodes", []),
        "diagnostics": report.get("diagnostics", []),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("result", type=Path)
    parser.add_argument("--evaluated-at", required=True)
    parser.add_argument("--validator-source-revision", required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    try:
        report = review_result(
            args.result,
            evaluated_at=args.evaluated_at,
            validator_source_revision=args.validator_source_revision,
        )
    except (
        OSError,
        ValueError,
        Power2ValidationError,
    ) as error:
        report = {
            "schemaVersion":
                "power-runner-certification-review-1.0.0-draft.1",
            "reviewedAt": args.evaluated_at,
            "validator": {
                "name": VALIDATOR_NAME,
                "version": VALIDATOR_VERSION,
                "sourceRevision": args.validator_source_revision,
            },
            "status": "fail",
            "physicalDeviceSmokeRun": "fail",
            "rawResultReview": "fail",
            "publishable": False,
            "rankingEligible": False,
            "reasonCodes": ["certification-review-failed"],
            "diagnostics": [str(error)],
        }
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
