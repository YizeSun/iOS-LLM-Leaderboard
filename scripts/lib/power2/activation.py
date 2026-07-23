"""Deterministically stage the final Power 2 App release and active pointer."""

from __future__ import annotations

import hashlib
import json
import re
import uuid
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any

try:
    from scripts.review_power2_app_release_result import review_result
except ModuleNotFoundError:
    from review_power2_app_release_result import review_result


ROOT = Path(__file__).resolve().parents[3]
CANDIDATE_PATH = ROOT / "products/power/candidate.json"
REGISTRY_PATH = ROOT / "products/power/registry.json"
CURRENT_PATH = ROOT / "products/power/current.json"
APP_RELEASE_ROOT = ROOT / "products/power/app-releases"
APP_EVIDENCE_ROOT = APP_RELEASE_ROOT / "evidence"
APP_COMPONENT_PATH = ROOT / "apps/ios/component-manifest.json"


class Power2ActivationError(ValueError):
    """Raised when the final activation cannot be issued safely."""


@dataclass(frozen=True)
class ActivationFiles:
    """Complete file set that one reviewed activation commit must add/update."""

    files: dict[Path, bytes]
    summary: dict[str, Any]


def _json_bytes(value: dict[str, Any]) -> bytes:
    return (
        json.dumps(value, indent=2, sort_keys=True) + "\n"
    ).encode("utf-8")


def _json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise Power2ActivationError(
            f"cannot read activation input {path}: {error}"
        ) from error
    if not isinstance(value, dict):
        raise Power2ActivationError(
            f"activation input is not an object: {path}"
        )
    return value


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256(path: Path) -> str:
    return _sha256_bytes(path.read_bytes())


def _repo_path(relative_path: str) -> Path:
    pure = PurePosixPath(relative_path)
    if pure.is_absolute() or ".." in pure.parts:
        raise Power2ActivationError(
            f"unsafe repository path: {relative_path}"
        )
    path = (ROOT / pure).resolve()
    try:
        path.relative_to(ROOT.resolve())
    except ValueError as error:
        raise Power2ActivationError(
            f"repository path escapes root: {relative_path}"
        ) from error
    return path


def _reference(
    value: Any,
    label: str,
) -> tuple[Path, dict[str, str]]:
    if not isinstance(value, dict):
        raise Power2ActivationError(f"{label} is not a reference")
    relative_path = value.get("path")
    expected = value.get("sha256")
    if (
        not isinstance(relative_path, str)
        or not isinstance(expected, str)
        or not re.fullmatch(r"[0-9a-f]{64}", expected)
    ):
        raise Power2ActivationError(f"{label} is not a pinned reference")
    path = _repo_path(relative_path)
    if _sha256(path) != expected:
        raise Power2ActivationError(f"{label} digest mismatch")
    return path, {"path": relative_path, "sha256": expected}


def _rendered_reference(path: Path, contents: bytes) -> dict[str, str]:
    return {
        "path": path.relative_to(ROOT).as_posix(),
        "sha256": _sha256_bytes(contents),
    }


def _timestamp(value: str, label: str) -> str:
    if not re.fullmatch(
        r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z",
        value,
    ):
        raise Power2ActivationError(
            f"{label} must be an explicit UTC ISO-8601 timestamp"
        )
    return value


def _revision(value: str) -> str:
    if not re.fullmatch(r"(?:[0-9a-f]{40}|[0-9a-f]{64})", value):
        raise Power2ActivationError(
            "validator source revision must be 40 or 64 lowercase hex"
        )
    return value


def _active_entries(values: Any) -> list[dict[str, Any]]:
    if not isinstance(values, list):
        raise Power2ActivationError(
            "Power registry entries must be an array"
        )
    activated: list[dict[str, Any]] = []
    for value in values:
        if not isinstance(value, dict):
            raise Power2ActivationError(
                "Power registry contains an invalid entry"
            )
        entry = dict(value)
        candidate_version = entry.pop("candidateVersion", None)
        if not isinstance(candidate_version, str):
            raise Power2ActivationError(
                "Power registry entry has no candidate version"
            )
        entry["status"] = "active"
        entry["currentVersion"] = candidate_version
        activated.append(entry)
    return activated


def _review_failure_summary(review: dict[str, Any]) -> str:
    """Expose authoritative failed gates before advisory diagnostics."""

    parts = [f"classification={review.get('classification', 'unknown')}"]
    reason_codes = review.get("reasonCodes")
    if isinstance(reason_codes, list) and reason_codes:
        parts.append(
            "reasonCodes="
            + ",".join(str(reason) for reason in reason_codes)
        )
    checks = review.get("checks")
    if isinstance(checks, dict):
        failed_checks = [
            name
            for name, check in checks.items()
            if isinstance(check, dict) and check.get("status") == "fail"
        ]
        if failed_checks:
            parts.append("failedChecks=" + ",".join(failed_checks))
    diagnostics = review.get("diagnostics")
    if isinstance(diagnostics, list) and diagnostics:
        parts.append(
            "diagnostics=" + " | ".join(str(item) for item in diagnostics)
        )
    return "; ".join(parts)


def render_activation(
    result_path: Path,
    *,
    reviewed_at: str,
    validator_source_revision: str,
    activated_at: str,
) -> ActivationFiles:
    """Review one exact Official result and render the atomic release set."""

    reviewed_at = _timestamp(reviewed_at, "reviewed_at")
    activated_at = _timestamp(activated_at, "activated_at")
    validator_source_revision = _revision(validator_source_revision)
    if CURRENT_PATH.exists():
        raise Power2ActivationError(
            "Power current pointer already exists; activation is one-time"
        )

    candidate = _json(CANDIDATE_PATH)
    registry = _json(REGISTRY_PATH)
    if (
        candidate.get("schemaVersion")
        != "power-stack-pointer-1.0.0-draft.1"
        or candidate.get("status") != "migration-draft"
        or candidate.get("publicIntakeOpen") is not False
        or candidate.get("appRelease") is not None
    ):
        raise Power2ActivationError(
            "Power candidate is not a closed migration draft"
        )
    if (
        registry.get("schemaVersion")
        != "power-product-registry-1.0.0-draft.1"
        or registry.get("status") != "migration-draft"
        or registry.get("publicIntakeOpen") is not False
        or registry.get("currentStack") is not None
    ):
        raise Power2ActivationError(
            "Power registry is not ready for first activation"
        )

    _, measurement_stack = _reference(
        candidate.get("measurementStack"),
        "measurement stack",
    )
    _, runner_components = _reference(
        candidate.get("runnerCandidate"),
        "Runner components",
    )
    _, runner_certificate = _reference(
        candidate.get("runnerCertificate"),
        "Runner certificate",
    )
    app_candidate_path, app_candidate_reference = _reference(
        candidate.get("appReleaseCandidate"),
        "App release candidate",
    )
    app_candidate = _json(app_candidate_path)
    if (
        app_candidate.get("state") != "candidate"
        or app_candidate.get("verification", {}).get(
            "sourceAndDependencyIntegrity"
        )
        != "pass"
        or app_candidate.get("verification", {}).get(
            "genericIOSReleaseBuild"
        )
        != "pass"
    ):
        raise Power2ActivationError(
            "App release candidate has not passed automated verification"
        )

    result_path = Path(result_path)
    result_bytes = result_path.read_bytes()
    try:
        result = json.loads(result_bytes)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise Power2ActivationError(
            f"Official result is not valid JSON: {error}"
        ) from error
    if not isinstance(result, dict):
        raise Power2ActivationError("Official result must be an object")
    try:
        result_id = str(uuid.UUID(str(result.get("resultID"))))
    except ValueError as error:
        raise Power2ActivationError(
            "Official result has no canonical UUID result ID"
        ) from error

    review = review_result(
        result_path,
        evaluated_at=reviewed_at,
        validator_source_revision=validator_source_revision,
    )
    if (
        review.get("status") != "pass"
        or review.get("physicalDeviceEndToEndRehearsal") != "pass"
        or review.get("classification") != "auto-accept"
        or review.get("publishable") is not False
        or review.get("rankingEligible") is not False
    ):
        raise Power2ActivationError(
            "Official result did not pass the closed App release review: "
            + _review_failure_summary(review)
        )

    expected_app = {
        "version": app_candidate.get("version"),
        "build": app_candidate.get("build"),
        "sourceRevision": app_candidate.get("sourceRevision"),
        "embeddedMeasurementStackSHA256": measurement_stack["sha256"],
    }
    if result.get("appRelease") != expected_app:
        raise Power2ActivationError(
            "Official result does not match the exact App release candidate"
        )
    certificate_id = result.get("runnerCertificateID")
    if app_candidate.get("supportedRunnerCertificateIDs") != [certificate_id]:
        raise Power2ActivationError(
            "Official result does not use the candidate Runner certificate"
        )

    evidence_directory = APP_EVIDENCE_ROOT / result_id
    result_output = evidence_directory / "result.json"
    review_output = evidence_directory / "review.json"
    component_output = evidence_directory / "app-component-manifest.json"
    release_output = APP_RELEASE_ROOT / (
        f"power-app-{app_candidate['version']}-build."
        f"{app_candidate['build']}-"
        f"{app_candidate['sourceRevision'][:12]}.json"
    )
    for output in (
        result_output,
        review_output,
        component_output,
        release_output,
        CURRENT_PATH,
    ):
        if output.exists():
            raise Power2ActivationError(
                f"activation output already exists: "
                f"{output.relative_to(ROOT)}"
            )

    review_bytes = _json_bytes(review)
    component_bytes = APP_COMPONENT_PATH.read_bytes()
    if _sha256_bytes(component_bytes) != app_candidate["sourceRevision"]:
        raise Power2ActivationError(
            "current App component manifest no longer matches the candidate"
        )
    result_reference = _rendered_reference(result_output, result_bytes)
    review_reference = _rendered_reference(review_output, review_bytes)
    component_reference = _rendered_reference(
        component_output,
        component_bytes,
    )

    app_release = {
        "schemaVersion": "power-app-release-1.0.0",
        "productID": "power",
        "releaseID": (
            f"power-app-{app_candidate['version']}-build."
            f"{app_candidate['build']}-"
            f"{app_candidate['sourceRevision'][:12]}"
        ),
        "state": "supported",
        "issuedAt": activated_at,
        "version": app_candidate["version"],
        "build": app_candidate["build"],
        "sourceRevision": app_candidate["sourceRevision"],
        "bundleIdentifier": app_candidate["bundleIdentifier"],
        "buildConfiguration": "Official",
        "appComponents": component_reference,
        "embeddedMeasurementStack": measurement_stack,
        "supportedRunnerCertificateIDs": [certificate_id],
        "releaseEvidence": {
            "result": result_reference,
            "review": review_reference,
        },
        "verification": {
            "sourceAndDependencyIntegrity": "pass",
            "genericIOSReleaseBuild": "pass",
            "physicalDeviceEndToEndRehearsal": "pass",
            "rawResultReview": "pass",
        },
    }
    app_release_bytes = _json_bytes(app_release)
    app_release_reference = _rendered_reference(
        release_output,
        app_release_bytes,
    )

    current = {
        "schemaVersion": "power-stack-pointer-1.0.0",
        "productID": "power",
        "stackID": candidate["stackID"],
        "status": "active",
        "publicIntakeOpen": True,
        "activatedAt": activated_at,
        "measurementStack": measurement_stack,
        "runnerComponents": runner_components,
        "runnerCertificate": runner_certificate,
        "appRelease": app_release_reference,
        "activationEvidence": {
            "result": result_reference,
            "review": review_reference,
        },
    }
    current_bytes = _json_bytes(current)

    active_registry = {
        **registry,
        "schemaVersion": "power-product-registry-1.0.0",
        "status": "active",
        "publicIntakeOpen": True,
        "currentStack": "products/power/current.json",
        "activatedAt": activated_at,
        "programs": _active_entries(registry.get("programs")),
        "targets": _active_entries(registry.get("targets")),
    }
    registry_bytes = _json_bytes(active_registry)
    files = {
        result_output: result_bytes,
        review_output: review_bytes,
        component_output: component_bytes,
        release_output: app_release_bytes,
        CURRENT_PATH: current_bytes,
        REGISTRY_PATH: registry_bytes,
    }
    return ActivationFiles(
        files=files,
        summary={
            "status": "ready",
            "resultID": result_id,
            "sourceResultSHA256": result_reference["sha256"],
            "appRelease": app_release_reference,
            "currentPointer": "products/power/current.json",
            "publicIntakeOpen": True,
            "fileCount": len(files),
            "candidateReference": app_candidate_reference,
        },
    )


def write_activation(rendered: ActivationFiles) -> None:
    """Write a previously verified activation set for one atomic review."""

    for path, contents in rendered.files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(contents)
