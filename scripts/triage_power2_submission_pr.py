#!/usr/bin/env python3
"""Classify a Power 2 result-only pull request from the trusted base."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path, PurePosixPath
from typing import Any

try:
    from scripts.lib.power2.engine import (
        ROOT,
        ValidationContext,
        load_candidate_app_release_review_context,
        load_product_context,
        validate_package,
    )
except ModuleNotFoundError:
    from lib.power2.engine import (
        ROOT,
        ValidationContext,
        load_candidate_app_release_review_context,
        load_product_context,
        validate_package,
    )


INTAKE = PurePosixPath(
    "submissions/power/text-generation-performance/2.0.0/draft"
)
PACKAGE_FILES = {"submission.json", "result.json"}
MAX_PACKAGES_PER_PR = 10
UUID_PATTERN = re.compile(
    r"^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-"
    r"[1-5][0-9A-Fa-f]{3}-[89ABab][0-9A-Fa-f]{3}-"
    r"[0-9A-Fa-f]{12}$"
)


def _git(*args: str, cwd: Path = ROOT) -> bytes:
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout


def _changes(base_ref: str, head_ref: str) -> list[tuple[str, str]]:
    output = _git(
        "diff",
        "--name-status",
        "--no-renames",
        f"{base_ref}...{head_ref}",
    ).decode("utf-8")
    changes: list[tuple[str, str]] = []
    for line in output.splitlines():
        if not line:
            continue
        status, separator, path = line.partition("\t")
        if not separator:
            raise ValueError(f"unparseable git diff entry: {line}")
        changes.append((status, path))
    return changes


def _candidate_packages(
    changes: list[tuple[str, str]],
) -> tuple[dict[str, set[str]], list[str]]:
    packages: dict[str, set[str]] = {}
    errors: list[str] = []
    for status, raw_path in changes:
        path = PurePosixPath(raw_path)
        parts = path.parts
        if (
            status != "A"
            or len(parts) != len(INTAKE.parts) + 2
            or parts[: len(INTAKE.parts)] != INTAKE.parts
            or parts[-1] not in PACKAGE_FILES
        ):
            errors.append(f"non-result-only change: {status} {raw_path}")
            continue
        submission_id = parts[-2]
        if UUID_PATTERN.fullmatch(submission_id) is None:
            errors.append(
                f"invalid submission directory name: {submission_id}"
            )
            continue
        packages.setdefault(submission_id, set()).add(parts[-1])
    if not packages:
        errors.append("no Power 2 submission package was added")
    if len(packages) > MAX_PACKAGES_PER_PR:
        errors.append(
            f"a pull request may add at most {MAX_PACKAGES_PER_PR} packages"
        )
    for submission_id, names in sorted(packages.items()):
        if names != PACKAGE_FILES:
            missing = ", ".join(sorted(PACKAGE_FILES - names))
            errors.append(
                f"{submission_id}: incomplete package; missing {missing}"
            )
    return packages, errors


def _materialize_package(
    head_ref: str,
    submission_id: str,
    root: Path,
) -> Path:
    package = root / submission_id
    package.mkdir()
    for name in sorted(PACKAGE_FILES):
        source = (INTAKE / submission_id / name).as_posix()
        (package / name).write_bytes(
            _git("show", f"{head_ref}:{source}")
        )
    return package


def _accepted_result_digests(base_ref: str) -> set[str]:
    try:
        paths = _git(
            "ls-tree",
            "-r",
            "--name-only",
            base_ref,
            "--",
            INTAKE.as_posix(),
        ).decode("utf-8")
    except subprocess.CalledProcessError:
        return set()
    result_paths = [
        path
        for path in paths.splitlines()
        if PurePosixPath(path).name == "result.json"
    ]
    return {
        hashlib.sha256(_git("show", f"{base_ref}:{path}")).hexdigest()
        for path in result_paths
    }


def classify(
    base_ref: str,
    head_ref: str,
    expected_contributor: str,
    *,
    evaluated_at: str,
    validator_source_revision: str,
    context: ValidationContext | None = None,
) -> dict[str, Any]:
    changes = _changes(base_ref, head_ref)
    touches_intake = any(
        PurePosixPath(path).parts[: len(INTAKE.parts)] == INTAKE.parts
        for _status, path in changes
    )
    if not touches_intake:
        return {
            "schemaVersion": "power-2-submission-pr-triage-1.0.0-draft.1",
            "classification": "not_applicable",
            "expectedContributor": expected_contributor,
            "packageCount": 0,
            "reasonCodes": [],
            "errors": [],
            "packages": [],
        }

    package_names, change_errors = _candidate_packages(changes)
    report: dict[str, Any] = {
        "schemaVersion": "power-2-submission-pr-triage-1.0.0-draft.1",
        "classification": "rejected",
        "expectedContributor": expected_contributor,
        "packageCount": len(package_names),
        "reasonCodes": [],
        "errors": list(change_errors),
        "packages": [],
    }
    if change_errors:
        report["reasonCodes"].append("pull-request-scope-invalid")
        return report

    context = context or load_product_context()
    accepted_digests = _accepted_result_digests(base_ref)
    classifications: list[str] = []
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        for submission_id in sorted(package_names):
            package = _materialize_package(
                head_ref,
                submission_id,
                root,
            )
            package_report = validate_package(
                package,
                context=context,
                evaluated_at=evaluated_at,
                validator_source_revision=validator_source_revision,
                pr_author=expected_contributor,
                accepted_result_digests=accepted_digests,
            )
            result_digest = package_report["sourceResultSHA256"]
            accepted_digests.add(result_digest)
            classification = package_report["classification"]
            classifications.append(classification)
            report["packages"].append(
                {
                    "submissionID": submission_id,
                    "sourceResultSHA256": result_digest,
                    "classification": classification,
                    "reasonCodes": package_report["reasonCodes"],
                    "behaviorConformance": package_report["checks"][
                        "behaviorConformance"
                    ],
                    "recommendationEligibility": package_report["checks"][
                        "recommendationEligibility"
                    ],
                    "metricEligibility": package_report["checks"][
                        "metricEligibility"
                    ],
                }
            )
            if classification == "reject":
                report["reasonCodes"].extend(
                    package_report["reasonCodes"]
                )
                report["errors"].extend(
                    package_report.get("diagnostics", [])
                )

    report["reasonCodes"] = list(
        dict.fromkeys(report["reasonCodes"])
    )
    if "reject" in classifications:
        report["classification"] = "rejected"
    elif "manual-review" in classifications:
        report["classification"] = "manual_review"
    else:
        report["classification"] = "auto_accept"
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--expected-contributor", required=True)
    parser.add_argument("--evaluated-at", required=True)
    parser.add_argument("--validator-source-revision", required=True)
    parser.add_argument(
        "--app-release-rehearsal",
        action="store_true",
        help=(
            "classify against the exact closed Official App candidate "
            "without opening public intake"
        ),
    )
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    try:
        context = (
            load_candidate_app_release_review_context()
            if args.app_release_rehearsal
            else None
        )
        report = classify(
            args.base,
            args.head,
            args.expected_contributor,
            evaluated_at=args.evaluated_at,
            validator_source_revision=args.validator_source_revision,
            context=context,
        )
    except (
        OSError,
        UnicodeDecodeError,
        json.JSONDecodeError,
        ValueError,
        subprocess.CalledProcessError,
    ) as error:
        report = {
            "schemaVersion": "power-2-submission-pr-triage-1.0.0-draft.1",
            "classification": "rejected",
            "expectedContributor": args.expected_contributor,
            "packageCount": 0,
            "reasonCodes": ["triage-failed"],
            "errors": [str(error)],
            "packages": [],
        }
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 1 if report["classification"] == "rejected" else 0


if __name__ == "__main__":
    raise SystemExit(main())
