#!/usr/bin/env python3
"""Generate closed Power 2 Runner and App release candidate identities."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path, PurePosixPath
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CANDIDATE_PATH = ROOT / "products/power/candidate.json"
RUNNER_OUTPUT_PATH = (
    ROOT / "products/power/runner-certificates/candidate.json"
)
APP_OUTPUT_PATH = ROOT / "products/power/app-releases/candidate.json"

# This checkpoint records the exact identities that completed the automated
# candidate suite. Any stack, Runner, or App source change automatically
# returns the generated candidates to pending until the suite is rerun and
# this checkpoint is deliberately advanced.
AUTOMATED_VERIFICATION_CHECKPOINT = {
    "measurementStackSHA256":
        "43e5d8899f660c557e3a7dad0c7e54de8e440aab5be6d46096306c6e43b385a0",
    "runnerComponentsSHA256":
        "87f62feecc2b3fca994cc4f40214aed9876f1477c51fdb7c56c6945eb6b03ee2",
    "appComponentsSHA256":
        "6df4dca4863e3c583f2fb4670886c72c726014835923ebcecb47664353ddc3b4",
}


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _repo_path(relative_path: str) -> Path:
    pure_path = PurePosixPath(relative_path)
    if pure_path.is_absolute() or ".." in pure_path.parts:
        raise ValueError(f"unsafe repository path: {relative_path}")
    path = (ROOT / pure_path).resolve()
    path.relative_to(ROOT.resolve())
    return path


def _load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def _reference(
    value: Any,
    label: str,
) -> tuple[Path, dict[str, str]]:
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be an object")
    relative_path = value.get("path")
    digest = value.get("sha256")
    if not isinstance(relative_path, str) or not relative_path:
        raise ValueError(f"{label} has no path")
    if (
        not isinstance(digest, str)
        or len(digest) != 64
        or any(character not in "0123456789abcdef" for character in digest)
    ):
        raise ValueError(f"{label} has an invalid SHA-256")
    path = _repo_path(relative_path)
    if _sha256(path) != digest:
        raise ValueError(f"{label} digest mismatch: {relative_path}")
    return path, {"path": relative_path, "sha256": digest}


def _component_digest(
    manifest: dict[str, Any],
    name: str,
) -> str:
    components = manifest.get("components")
    if not isinstance(components, dict):
        raise ValueError("Runner component manifest has no components")
    component = components.get(name)
    if not isinstance(component, dict):
        raise ValueError(f"Runner component manifest has no {name}")
    digest = component.get("sha256")
    if not isinstance(digest, str):
        raise ValueError(f"Runner component {name} has no digest")
    return digest


def render_candidates() -> tuple[str, str]:
    candidate = _load_json(CANDIDATE_PATH)
    if (
        candidate.get("status") != "migration-draft"
        or candidate.get("publicIntakeOpen") is not False
        or candidate.get("appRelease") is not None
    ):
        raise ValueError("release candidates require a closed migration draft")

    stack_path, stack_reference = _reference(
        candidate.get("measurementStack"),
        "measurement stack",
    )
    runner_path, runner_reference = _reference(
        candidate.get("runnerCandidate"),
        "Runner component manifest",
    )
    app_path, app_reference = _reference(
        candidate.get("appCandidate"),
        "App component manifest",
    )
    stack = _load_json(stack_path)
    runner = _load_json(runner_path)
    app = _load_json(app_path)
    program_reference = stack.get("program")
    target_reference = stack.get("target")
    runner_policy_reference = (
        stack.get("policies", {}).get("runner")
        if isinstance(stack.get("policies"), dict)
        else None
    )
    _, program_reference = _reference(
        program_reference,
        "Program manifest",
    )
    _, target_reference = _reference(
        target_reference,
        "Target manifest",
    )
    _, runner_policy_reference = _reference(
        runner_policy_reference,
        "Runner certification policy",
    )
    runtime_path, runtime_reference = _reference(
        runner.get("runtimeIdentity"),
        "Runner runtime identity",
    )
    runtime = _load_json(runtime_path)
    runner_automated_verification_passed = (
        stack_reference["sha256"]
        == AUTOMATED_VERIFICATION_CHECKPOINT[
            "measurementStackSHA256"
        ]
        and runner_reference["sha256"]
        == AUTOMATED_VERIFICATION_CHECKPOINT[
            "runnerComponentsSHA256"
        ]
    )
    app_automated_verification_passed = (
        runner_automated_verification_passed
        and app_reference["sha256"]
        == AUTOMATED_VERIFICATION_CHECKPOINT[
            "appComponentsSHA256"
        ]
    )
    runner_automated_state = (
        "pass" if runner_automated_verification_passed else "pending"
    )
    app_automated_state = (
        "pass" if app_automated_verification_passed else "pending"
    )

    runner_candidate_id = (
        "power2-certification-candidate-" + runner_reference["sha256"][:12]
    )
    runner_candidate = {
        "schemaVersion":
            "power-runner-certificate-candidate-1.0.0-draft.1",
        "productID": "power",
        "certificateID": runner_candidate_id,
        "state": "candidate",
        "measurementStack": stack_reference,
        "certificationPolicy": runner_policy_reference,
        "programManifestSHA256": program_reference["sha256"],
        "targetManifestSHA256": target_reference["sha256"],
        "runnerComponents": runner_reference,
        "componentSHA256": {
            name: _component_digest(runner, name)
            for name in (
                "runnerCore",
                "programModule",
                "targetAdapter",
                "runtimeAdapter",
                "evidenceEnvelope",
            )
        },
        "runtimeIdentity": runtime_reference,
        "runtime": {
            key: runtime[key]
            for key in (
                "name",
                "version",
                "resolvedRevision",
                "backend",
                "configuration",
            )
        },
        "verification": {
            "sourceAndDependencyIntegrity": "pass",
            "unitTests": runner_automated_state,
            "schemaAndFixtureIntegrity": runner_automated_state,
            "deterministicSerialization": runner_automated_state,
            "failurePreservation": runner_automated_state,
            "genericIOSReleaseBuild": runner_automated_state,
            "physicalDeviceSmokeRun": "pending",
            "rawResultReview": "pending",
        },
        "issuanceBlockedBy": [
            "run the Certification build on a physical iPhone",
            "review the exact raw Certification evidence",
        ] + (
            []
            if runner_automated_verification_passed
            else ["complete automated verification"]
        ),
    }

    app_candidate_id = (
        "power-app-2.0.0-candidate-" + app_reference["sha256"][:12]
    )
    app_candidate = {
        "schemaVersion": "power-app-release-candidate-1.0.0-draft.1",
        "productID": "power",
        "releaseID": app_candidate_id,
        "state": "candidate",
        "version": "2.0.0",
        "build": "1",
        "sourceRevision": app_reference["sha256"],
        "bundleIdentifier": "org.iosllmleaderboard.power2",
        "buildConfiguration": "Official",
        "appComponents": app_reference,
        "embeddedMeasurementStack": stack_reference,
        "supportedRunnerCertificationCandidateIDs": [
            runner_candidate_id
        ],
        "verification": {
            "sourceAndDependencyIntegrity": "pass",
            "genericIOSReleaseBuild": app_automated_state,
            "physicalDeviceEndToEndRehearsal": "pending",
        },
        "releaseBlockedBy": [
            "issue the bound Runner certificate",
            "complete a physical-device end-to-end rehearsal",
            "activate the immutable stack and public intake atomically",
        ] + (
            []
            if app_automated_verification_passed
            else ["complete the Official generic iOS Release build"]
        ),
    }

    return (
        json.dumps(runner_candidate, indent=2, sort_keys=True) + "\n",
        json.dumps(app_candidate, indent=2, sort_keys=True) + "\n",
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail instead of rewriting stale candidate identities",
    )
    args = parser.parse_args(argv)
    try:
        expected_runner, expected_app = render_candidates()
    except (KeyError, OSError, ValueError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    if args.check:
        stale = []
        for path, expected in (
            (RUNNER_OUTPUT_PATH, expected_runner),
            (APP_OUTPUT_PATH, expected_app),
        ):
            try:
                actual = path.read_text(encoding="utf-8")
            except OSError:
                actual = ""
            if actual != expected:
                stale.append(str(path.relative_to(ROOT)))
        if stale:
            print(
                "error: stale generated release candidates: "
                + ", ".join(stale),
                file=sys.stderr,
            )
            return 1
        return 0

    RUNNER_OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    APP_OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    RUNNER_OUTPUT_PATH.write_text(expected_runner, encoding="utf-8")
    APP_OUTPUT_PATH.write_text(expected_app, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
