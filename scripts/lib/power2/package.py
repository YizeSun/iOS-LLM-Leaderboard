"""Create immutable two-file Power 2 submission packages."""

from __future__ import annotations

import hashlib
import json
import re
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from . import json_schema
from .engine import (
    ROOT,
    ValidationContext,
    _contract_reasons,
    load_product_context,
)


DEFAULT_SUBMISSION_ROOT = (
    ROOT
    / "submissions"
    / "power"
    / "text-generation-performance"
    / "2.0.0"
    / "draft"
)
GITHUB_LOGIN = re.compile(
    r"^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$"
)


def _timestamp(value: str | None) -> str:
    if value is not None:
        return value
    return (
        datetime.now(timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )


def create_package(
    result_path: Path,
    output_root: Path = DEFAULT_SUBMISSION_ROOT,
    *,
    github_login: str,
    conflict_of_interest: str = "none",
    disclosure: str | None = None,
    environment_notes: str | None = None,
    declarations_accepted: bool,
    submission_id: str | None = None,
    created_at: str | None = None,
    context: ValidationContext | None = None,
) -> Path:
    """Write a package while preserving ``result.json`` byte-for-byte."""

    if not declarations_accepted:
        raise ValueError(
            "declarations must be reviewed and explicitly accepted"
        )
    login = github_login.strip()
    if GITHUB_LOGIN.fullmatch(login) is None:
        raise ValueError("invalid GitHub login")
    if conflict_of_interest not in {"none", "disclosed"}:
        raise ValueError("unsupported conflict-of-interest value")
    normalized_disclosure = (
        disclosure.strip() if isinstance(disclosure, str) else None
    )
    if (
        conflict_of_interest == "disclosed"
        and not normalized_disclosure
    ):
        raise ValueError("a disclosed conflict requires an explanation")

    context = context or load_product_context()
    result_path = Path(result_path)
    result_bytes = result_path.read_bytes()
    try:
        result = json.loads(result_bytes)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError(f"result is not valid JSON: {error}") from error
    if not isinstance(result, dict):
        raise ValueError("result must be a JSON object")
    shape_errors = json_schema.validate(
        result,
        context.schema_paths["evidence"],
        ROOT,
    )
    if shape_errors:
        raise ValueError(
            "result does not match the Power 2 envelope: "
            + "; ".join(shape_errors)
        )
    diagnostics: list[str] = []
    contract_reasons = _contract_reasons(
        result,
        context,
        diagnostics,
    )
    if contract_reasons:
        detail = "; ".join(contract_reasons + diagnostics)
        raise ValueError(
            "result does not match the selected Power 2 stack: " + detail
        )

    identifier = submission_id or str(uuid.uuid4())
    try:
        parsed_identifier = uuid.UUID(identifier)
    except ValueError as error:
        raise ValueError("submission ID must be a UUID") from error
    if str(parsed_identifier) != identifier.casefold():
        identifier = str(parsed_identifier)

    notes = (
        environment_notes.strip()
        if isinstance(environment_notes, str)
        else None
    )
    submission: dict[str, Any] = {
        "schemaVersion": "power-submission-1.0.0-draft.1",
        "submissionID": identifier,
        "createdAt": _timestamp(created_at),
        "contributor": {
            "githubLogin": login,
            "conflictOfInterest": conflict_of_interest,
        },
        "sourceResult": {
            "path": "result.json",
            "sha256": hashlib.sha256(result_bytes).hexdigest(),
            "schemaVersion": result["schemaVersion"],
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
    if conflict_of_interest == "disclosed":
        submission["contributor"]["disclosure"] = normalized_disclosure
    if notes:
        submission["environmentNotes"] = notes

    submission_errors = json_schema.validate(
        submission,
        context.schema_paths["submission"],
        ROOT,
    )
    if submission_errors:
        raise RuntimeError(
            "package generator emitted an invalid submission: "
            + "; ".join(submission_errors)
        )

    package = Path(output_root) / identifier
    if package.exists():
        raise ValueError(f"submission package already exists: {package}")
    package.mkdir(parents=True)
    (package / "result.json").write_bytes(result_bytes)
    (package / "submission.json").write_text(
        json.dumps(submission, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    if (package / "result.json").read_bytes() != result_bytes:
        raise RuntimeError("result bytes changed while creating the package")
    return package
