#!/usr/bin/env python3
"""Repository control plane for versioned benchmark products.

The first supported operation verifies the inactive Power 2.0 candidate stack.
It is intentionally read-only: activation requires a separately reviewed
released stack and is not a side effect of verification.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[1]
POWER_REGISTRY_PATH = "products/power/registry.json"
POWER_CURRENT_PATH = "products/power/current.json"

# Active Power 2.0 JSON may not dispatch to or derive identity from the retired
# Power major. Historical files remain elsewhere for audit only.
FORBIDDEN_ACTIVE_REFERENCE_FRAGMENTS = (
    "power-1.",
    "suite-b",
    "benchmarks/",
    "submissions/",
    "results/",
    "1.1.0-rc",
)


class VerificationError(ValueError):
    """Raised when a candidate stack is incomplete, inconsistent, or unsafe."""


def _load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise VerificationError(f"missing JSON asset: {path}") from error
    except json.JSONDecodeError as error:
        raise VerificationError(f"invalid JSON in {path}: {error}") from error
    if not isinstance(value, dict):
        raise VerificationError(f"expected a JSON object: {path}")
    return value


def _repo_path(relative_path: str) -> Path:
    pure_path = PurePosixPath(relative_path)
    if pure_path.is_absolute() or ".." in pure_path.parts:
        raise VerificationError(f"unsafe repository path: {relative_path}")
    resolved = (ROOT / pure_path).resolve()
    try:
        resolved.relative_to(ROOT.resolve())
    except ValueError as error:
        raise VerificationError(
            f"path escapes repository root: {relative_path}"
        ) from error
    return resolved


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _verify_pinned_asset(reference: dict[str, Any], context: str) -> Path:
    relative_path = reference.get("path")
    expected_digest = reference.get("sha256")
    if not isinstance(relative_path, str) or not relative_path:
        raise VerificationError(f"{context} has no path")
    if (
        not isinstance(expected_digest, str)
        or len(expected_digest) != 64
        or any(character not in "0123456789abcdef" for character in expected_digest)
    ):
        raise VerificationError(f"{context} has an invalid SHA-256")

    path = _repo_path(relative_path)
    if not path.is_file():
        raise VerificationError(f"{context} does not exist: {relative_path}")
    actual_digest = _sha256(path)
    if actual_digest != expected_digest:
        raise VerificationError(
            f"{context} digest mismatch: expected {expected_digest}, "
            f"found {actual_digest}"
        )
    return path


def _walk_strings(value: Any) -> Iterable[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for key, child in value.items():
            yield str(key)
            yield from _walk_strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_strings(child)


def _reject_legacy_references(
    documents: Iterable[tuple[str, dict[str, Any]]],
) -> None:
    for label, document in documents:
        for value in _walk_strings(document):
            lowered = value.lower()
            for fragment in FORBIDDEN_ACTIVE_REFERENCE_FRAGMENTS:
                if fragment in lowered:
                    raise VerificationError(
                        f"active Power 2.0 asset {label} references retired "
                        f"surface {fragment!r}: {value!r}"
                    )


def _verify_program_manifest(
    manifest_path: Path,
    manifest: dict[str, Any],
) -> tuple[list[tuple[str, dict[str, Any]]], int]:
    if manifest.get("noLegacyDependencies") is not True:
        raise VerificationError(
            "program manifest must declare noLegacyDependencies=true"
        )
    if manifest.get("publicIntakeOpen") is not False:
        raise VerificationError("draft program must keep public intake closed")

    assets = manifest.get("assets")
    if not isinstance(assets, list) or not assets:
        raise VerificationError("program manifest has no pinned assets")

    documents: list[tuple[str, dict[str, Any]]] = [
        (str(manifest_path.relative_to(ROOT)), manifest)
    ]
    listed_paths: set[Path] = set()
    for index, reference in enumerate(assets):
        if not isinstance(reference, dict):
            raise VerificationError(
                f"program manifest asset {index} is not an object"
            )
        asset_path = _verify_pinned_asset(
            reference, f"program manifest asset {index}"
        )
        if asset_path in listed_paths:
            raise VerificationError(
                f"program manifest pins an asset twice: {asset_path}"
            )
        listed_paths.add(asset_path)
        if asset_path.suffix == ".json":
            documents.append(
                (str(asset_path.relative_to(ROOT)), _load_json(asset_path))
            )

    version_root = manifest_path.parent
    actual_paths = {
        path.resolve()
        for path in version_root.rglob("*")
        if path.is_file() and path.resolve() != manifest_path.resolve()
    }
    if listed_paths != actual_paths:
        missing = sorted(
            str(path.relative_to(ROOT)) for path in actual_paths - listed_paths
        )
        stale = sorted(
            str(path.relative_to(ROOT)) for path in listed_paths - actual_paths
        )
        raise VerificationError(
            "program manifest does not exactly cover the version directory; "
            f"unlisted={missing}, stale={stale}"
        )

    return documents, len(assets)


def _verify_workload_fixtures(
    contract: dict[str, Any],
    documents_by_path: dict[str, dict[str, Any]],
) -> None:
    workloads = contract.get("workloads")
    if not isinstance(workloads, list) or not workloads:
        raise VerificationError("program contract has no workloads")
    for workload_reference in workloads:
        if not isinstance(workload_reference, dict):
            raise VerificationError("invalid workload reference")
        workload_path = workload_reference.get("path")
        if not isinstance(workload_path, str):
            raise VerificationError("workload reference has no path")
        workload = documents_by_path.get(workload_path)
        if workload is None:
            raise VerificationError(
                f"workload is not pinned by the program manifest: {workload_path}"
            )
        if workload.get("workloadID") != workload_reference.get("id"):
            raise VerificationError(f"workload ID mismatch: {workload_path}")
        if workload.get("workloadVersion") != workload_reference.get("version"):
            raise VerificationError(
                f"workload version mismatch: {workload_path}"
            )

        fixture = workload.get("fixture")
        if not isinstance(fixture, dict):
            raise VerificationError(f"workload has no fixture: {workload_path}")
        _verify_pinned_asset(fixture, f"fixture for {workload_path}")


def _verify_workload_measurement_modes(
    contract: dict[str, Any],
    documents_by_path: dict[str, dict[str, Any]],
) -> None:
    payload_schema = next(
        (
            document
            for path, document in documents_by_path.items()
            if PurePosixPath(path).name
            == "text-generation-payload.schema.json"
        ),
        None,
    )
    if not isinstance(payload_schema, dict):
        raise VerificationError("program has no text payload schema")
    try:
        allowed_modes = set(
            payload_schema["properties"]["measurementMode"]["enum"]
        )
    except (KeyError, TypeError) as error:
        raise VerificationError(
            "text payload schema has no measurement-mode enum"
        ) from error
    if not allowed_modes or not all(
        isinstance(mode, str) for mode in allowed_modes
    ):
        raise VerificationError(
            "text payload schema has an invalid measurement-mode enum"
        )

    for workload_reference in contract["workloads"]:
        workload_path = workload_reference["path"]
        workload = documents_by_path[workload_path]
        mode = workload.get("measurementMode")
        if mode not in allowed_modes:
            raise VerificationError(
                f"workload measurement mode is not accepted by its payload "
                f"schema: {workload_path}: {mode!r}"
            )


def _verify_schema_set(
    documents_by_path: dict[str, dict[str, Any]],
) -> int:
    schema_paths = [
        path
        for path in documents_by_path
        if "/schemas/" in path and path.endswith(".schema.json")
    ]
    required_names = {
        "evidence-envelope.schema.json",
        "text-generation-payload.schema.json",
        "submission.schema.json",
        "validation-report.schema.json",
        "review-record.schema.json",
    }
    actual_names = {PurePosixPath(path).name for path in schema_paths}
    if actual_names != required_names:
        raise VerificationError(
            "program schema set mismatch; "
            f"expected={sorted(required_names)}, found={sorted(actual_names)}"
        )
    for path in schema_paths:
        schema = documents_by_path[path]
        if schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
            raise VerificationError(
                f"schema does not declare JSON Schema 2020-12: {path}"
            )
        if not isinstance(schema.get("$id"), str):
            raise VerificationError(f"schema has no stable $id: {path}")
    return len(schema_paths)


def _verify_runner_candidate(
    reference: dict[str, Any],
    documents: list[tuple[str, dict[str, Any]]],
) -> tuple[int, bool]:
    manifest_path = _verify_pinned_asset(
        reference, "candidate runner component manifest"
    )
    manifest = _load_json(manifest_path)
    documents.append((str(manifest_path.relative_to(ROOT)), manifest))
    if (
        manifest.get("schemaVersion")
        != "power-runner-component-manifest-1.0.0-draft.1"
    ):
        raise VerificationError(
            "candidate runner has an unsupported component manifest"
        )
    if manifest.get("status") != "migration-draft":
        raise VerificationError("candidate runner is not a migration draft")

    package_reference = manifest.get("packageManifest")
    if not isinstance(package_reference, dict):
        raise VerificationError("candidate runner has no Package.swift pin")
    _verify_pinned_asset(package_reference, "candidate runner Package.swift")
    dependency_lock_reference = manifest.get("resolvedDependencies")
    if not isinstance(dependency_lock_reference, dict):
        raise VerificationError(
            "candidate runner has no Package.resolved pin"
        )
    _verify_pinned_asset(
        dependency_lock_reference,
        "candidate runner Package.resolved",
    )

    components = manifest.get("components")
    if not isinstance(components, dict):
        raise VerificationError("candidate runner has no components")
    expected_roots = {
        "evidenceEnvelope": "apps/PowerRunnerKit/Sources/PowerEvidence",
        "runnerCore": "apps/PowerRunnerKit/Sources/PowerRunnerCore",
        "programModule": "apps/PowerRunnerKit/Sources/PowerTextProgram",
        "targetAdapter": "apps/PowerRunnerKit/Sources/PowerAppleTarget",
        "runtimeAdapter": "apps/PowerRunnerKit/Sources/PowerMLXRuntime",
    }
    for component_name, source_root in expected_roots.items():
        component = components.get(component_name)
        if not isinstance(component, dict):
            raise VerificationError(
                f"candidate runner has no {component_name} component"
            )
        if component.get("sourceRoot") != source_root:
            raise VerificationError(
                f"candidate runner {component_name} source root mismatch"
            )
        files = component.get("files")
        expected_digest = component.get("sha256")
        if not isinstance(files, list) or not files:
            raise VerificationError(
                f"candidate runner {component_name} has no source files"
            )
        listed_paths: set[Path] = set()
        for index, file_reference in enumerate(files):
            if not isinstance(file_reference, dict):
                raise VerificationError(
                    f"candidate runner {component_name} file {index} "
                    "is invalid"
                )
            listed_paths.add(
                _verify_pinned_asset(
                    file_reference,
                    f"candidate runner {component_name} file {index}",
                ).resolve()
            )
        actual_paths = {
            path.resolve()
            for path in _repo_path(source_root).glob("*.swift")
            if path.is_file()
        }
        if listed_paths != actual_paths:
            raise VerificationError(
                f"candidate runner {component_name} file coverage mismatch"
            )
        canonical = json.dumps(
            files,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        actual_digest = hashlib.sha256(canonical).hexdigest()
        if expected_digest != actual_digest:
            raise VerificationError(
                f"candidate runner {component_name} aggregate digest "
                "mismatch"
            )

    runtime_adapter = components.get("runtimeAdapter")
    runtime_implemented = isinstance(runtime_adapter, dict)
    complete = manifest.get("completeForCertification")
    if complete is True and not runtime_implemented:
        raise VerificationError(
            "runner cannot be complete without a Runtime Adapter"
        )
    if complete is not False:
        raise VerificationError(
            "migration candidate must remain incomplete before certification"
        )
    return len(expected_roots), runtime_implemented


def _verify_app_candidate(
    reference: dict[str, Any],
    documents: list[tuple[str, dict[str, Any]]],
) -> int:
    manifest_path = _verify_pinned_asset(
        reference, "candidate App component manifest"
    )
    manifest = _load_json(manifest_path)
    documents.append((str(manifest_path.relative_to(ROOT)), manifest))
    if (
        manifest.get("schemaVersion")
        != "power-app-component-manifest-1.0.0-draft.1"
    ):
        raise VerificationError(
            "candidate App has an unsupported component manifest"
        )
    if manifest.get("status") != "migration-draft":
        raise VerificationError("candidate App is not a migration draft")

    required_pins = {
        "xcodeProject": "apps/ios/PowerBenchmarkApp.xcodeproj/project.pbxproj",
        "resolvedDependencies":
            "apps/ios/PowerBenchmarkApp.xcodeproj/"
            "project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
        "supportPackage": "apps/PowerAppKit/Package.swift",
        "supportPackageDependencies": "apps/PowerAppKit/Package.resolved",
    }
    for name, expected_path in required_pins.items():
        pin = manifest.get(name)
        if not isinstance(pin, dict) or pin.get("path") != expected_path:
            raise VerificationError(
                f"candidate App {name} pin is missing or misplaced"
            )
        _verify_pinned_asset(pin, f"candidate App {name}")

    expected_paths = {
        "appShell": {
            *(
                path.resolve()
                for path in (
                    ROOT / "apps" / "ios" / "PowerBenchmarkApp"
                ).glob("*.swift")
            ),
            (
                ROOT
                / "apps"
                / "ios"
                / "Power2CandidateIdentity.generated.swift"
            ).resolve(),
        },
        "resultsStore": {
            path.resolve()
            for path in (
                ROOT
                / "apps"
                / "PowerAppKit"
                / "Sources"
                / "PowerResultsStore"
            ).glob("*.swift")
        },
        "submissionKit": {
            path.resolve()
            for path in (
                ROOT
                / "apps"
                / "PowerAppKit"
                / "Sources"
                / "PowerSubmissionKit"
            ).glob("*.swift")
        },
        "githubSubmission": {
            path.resolve()
            for path in (
                ROOT
                / "apps"
                / "PowerAppKit"
                / "Sources"
                / "PowerGitHubSubmission"
            ).glob("*.swift")
        },
    }
    components = manifest.get("components")
    if not isinstance(components, dict):
        raise VerificationError("candidate App has no components")
    if set(components) != set(expected_paths):
        raise VerificationError(
            "candidate App component set does not match the approved design"
        )
    for name, actual_paths in expected_paths.items():
        component = components.get(name)
        if not isinstance(component, dict):
            raise VerificationError(
                f"candidate App has no {name} component"
            )
        files = component.get("files")
        if not isinstance(files, list) or not files:
            raise VerificationError(
                f"candidate App {name} has no source files"
            )
        listed_paths: set[Path] = set()
        for index, file_reference in enumerate(files):
            if not isinstance(file_reference, dict):
                raise VerificationError(
                    f"candidate App {name} file {index} is invalid"
                )
            listed_paths.add(
                _verify_pinned_asset(
                    file_reference,
                    f"candidate App {name} file {index}",
                ).resolve()
            )
        if listed_paths != actual_paths:
            raise VerificationError(
                f"candidate App {name} file coverage mismatch"
            )
        canonical = json.dumps(
            files,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        if component.get("sha256") != hashlib.sha256(
            canonical
        ).hexdigest():
            raise VerificationError(
                f"candidate App {name} aggregate digest mismatch"
            )

    if manifest.get("completeForRelease") is not False:
        raise VerificationError(
            "candidate App must remain unreleased before cutover"
        )
    return len(expected_paths)


def _verify_model_registry(
    registry: dict[str, Any],
    cohort: dict[str, Any],
    documents: list[tuple[str, dict[str, Any]]],
) -> int:
    entries = registry.get("entries")
    if not isinstance(entries, list) or not entries:
        raise VerificationError(
            "Power candidate must register at least one exact rerun artifact"
        )

    predicate = cohort.get("predicate")
    if not isinstance(predicate, dict):
        raise VerificationError("model cohort has no predicate")
    if predicate.get("field") != "parameterCount":
        raise VerificationError("candidate cohort must use parameterCount")
    if predicate.get("operator") != "less-than-or-equal":
        raise VerificationError("candidate cohort operator is unsupported")
    cohort_limit = predicate.get("value")
    if not isinstance(cohort_limit, int) or cohort_limit < 1:
        raise VerificationError("candidate cohort has no positive size limit")

    entry_ids: set[str] = set()
    referenced_paths: set[Path] = set()
    required_manifest_fields = {
        "publisher",
        "family",
        "artifactID",
        "artifactRevision",
        "parameterCount",
        "quantization",
        "format",
        "repositorySizeBytes",
        "tokenizer",
        "runtimeCompatibility",
        "licenseIdentifier",
        "licenseSourceURL",
        "sourceURL",
    }

    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            raise VerificationError(f"model registry entry {index} is invalid")
        entry_id = entry.get("registryEntryID")
        if not isinstance(entry_id, str) or not entry_id:
            raise VerificationError(f"model registry entry {index} has no ID")
        if entry_id in entry_ids:
            raise VerificationError(f"duplicate model registry ID: {entry_id}")
        entry_ids.add(entry_id)

        manifest_path = _verify_pinned_asset(
            entry, f"model registry entry {entry_id}"
        )
        referenced_paths.add(manifest_path)
        manifest = _load_json(manifest_path)
        documents.append((str(manifest_path.relative_to(ROOT)), manifest))

        if manifest.get("registryEntryID") != entry_id:
            raise VerificationError(
                f"model manifest ID mismatch for {entry_id}"
            )
        if manifest.get("status") != "rerun-candidate":
            raise VerificationError(
                f"model {entry_id} is not a rerun candidate"
            )
        missing_fields = sorted(required_manifest_fields - manifest.keys())
        if missing_fields:
            raise VerificationError(
                f"model {entry_id} is missing fields: {missing_fields}"
            )
        if manifest.get("oldRankingStatusImported") is not False:
            raise VerificationError(
                f"model {entry_id} imports retired ranking state"
            )
        if (
            manifest.get("performanceClaimsRequireNewAcceptedEvidence")
            is not True
        ):
            raise VerificationError(
                f"model {entry_id} does not require new evidence"
            )
        runtime_compatibility = manifest.get("runtimeCompatibility")
        if (
            not isinstance(runtime_compatibility, dict)
            or runtime_compatibility.get("runtime") != "MLX Swift LM"
            or not isinstance(
                runtime_compatibility.get(
                    "extraEndOfSequenceTokens"
                ),
                list,
            )
            or not all(
                isinstance(value, str) and value
                for value in runtime_compatibility.get(
                    "extraEndOfSequenceTokens", []
                )
            )
        ):
            raise VerificationError(
                f"model {entry_id} has invalid runtime compatibility"
            )

        artifact_revision = manifest.get("artifactRevision")
        source_url = manifest.get("sourceURL")
        if (
            not isinstance(artifact_revision, str)
            or len(artifact_revision) != 40
            or any(
                character not in "0123456789abcdef"
                for character in artifact_revision
            )
        ):
            raise VerificationError(
                f"model {entry_id} has an invalid artifact revision"
            )
        if (
            not isinstance(source_url, str)
            or artifact_revision not in source_url
        ):
            raise VerificationError(
                f"model {entry_id} source URL is not revision-pinned"
            )

        parameter_count = manifest.get("parameterCount")
        if not isinstance(parameter_count, int) or parameter_count < 1:
            raise VerificationError(
                f"model {entry_id} has no exact parameter count"
            )
        if parameter_count > cohort_limit:
            raise VerificationError(
                f"model {entry_id} is outside the selected cohort"
            )
        base_model = manifest.get("baseModel")
        if (
            not isinstance(base_model, dict)
            or base_model.get("parameterCount") != parameter_count
        ):
            raise VerificationError(
                f"model {entry_id} base parameter identity does not match"
            )

        weights = manifest.get("weights")
        if not isinstance(weights, list) or not weights:
            raise VerificationError(f"model {entry_id} has no pinned weights")
        for weight in weights:
            if (
                not isinstance(weight, dict)
                or not isinstance(weight.get("byteCount"), int)
                or not isinstance(weight.get("sha256"), str)
                or len(weight["sha256"]) != 64
            ):
                raise VerificationError(
                    f"model {entry_id} has an invalid weight record"
                )

        tokenizer = manifest.get("tokenizer")
        if (
            not isinstance(tokenizer, dict)
            or not isinstance(tokenizer.get("sha256"), str)
            or len(tokenizer["sha256"]) != 64
            or not isinstance(tokenizer.get("files"), list)
            or not tokenizer["files"]
        ):
            raise VerificationError(
                f"model {entry_id} has no pinned tokenizer identity"
            )

    actual_paths = {
        path.resolve()
        for path in (ROOT / "models" / "artifacts").rglob("manifest.json")
    }
    if referenced_paths != actual_paths:
        unregistered = sorted(
            str(path.relative_to(ROOT))
            for path in actual_paths - referenced_paths
        )
        missing = sorted(
            str(path.relative_to(ROOT))
            for path in referenced_paths - actual_paths
        )
        raise VerificationError(
            "model registry does not exactly cover artifact manifests; "
            f"unregistered={unregistered}, missing={missing}"
        )

    return len(entries)


def verify_power_candidate() -> dict[str, Any]:
    registry_path = _repo_path(POWER_REGISTRY_PATH)
    registry = _load_json(registry_path)
    if registry.get("status") != "migration-draft":
        raise VerificationError("Power registry is not a migration draft")
    if registry.get("publicIntakeOpen") is not False:
        raise VerificationError("Power public intake must remain closed")
    if registry.get("currentStack") is not None:
        raise VerificationError("Power currentStack must remain null before cutover")
    if _repo_path(POWER_CURRENT_PATH).exists():
        raise VerificationError(
            "products/power/current.json must not exist before activation"
        )

    candidate_path_value = registry.get("candidateStack")
    if not isinstance(candidate_path_value, str):
        raise VerificationError("Power registry has no candidate stack")
    candidate_path = _repo_path(candidate_path_value)
    candidate = _load_json(candidate_path)
    if candidate.get("status") != "migration-draft":
        raise VerificationError("Power candidate is not a migration draft")
    if candidate.get("publicIntakeOpen") is not False:
        raise VerificationError("Power candidate unexpectedly opens intake")
    if candidate.get("appRelease") is not None:
        raise VerificationError("unreleased App must not be activated")

    documents: list[tuple[str, dict[str, Any]]] = [
        (POWER_REGISTRY_PATH, registry),
        (candidate_path_value, candidate),
    ]

    runner_candidate_reference = candidate.get("runnerCandidate")
    if not isinstance(runner_candidate_reference, dict):
        raise VerificationError("Power candidate has no runner candidate")
    runner_component_count, runtime_adapter_implemented = (
        _verify_runner_candidate(runner_candidate_reference, documents)
    )
    app_candidate_reference = candidate.get("appCandidate")
    if not isinstance(app_candidate_reference, dict):
        raise VerificationError("Power candidate has no App candidate")
    app_component_count = _verify_app_candidate(
        app_candidate_reference,
        documents,
    )

    measurement_stack_reference = candidate.get("measurementStack")
    if not isinstance(measurement_stack_reference, dict):
        raise VerificationError("candidate has no measurement stack")
    measurement_stack_path = _verify_pinned_asset(
        measurement_stack_reference, "candidate measurement stack"
    )
    measurement_stack = _load_json(measurement_stack_path)
    documents.append(
        (str(measurement_stack_path.relative_to(ROOT)), measurement_stack)
    )
    if measurement_stack.get("status") != "migration-draft":
        raise VerificationError("measurement stack is not a migration draft")
    if measurement_stack.get("stackID") != candidate.get("stackID"):
        raise VerificationError("candidate and measurement stack IDs differ")
    if measurement_stack.get("runnerCertificate") is not None:
        raise VerificationError("uncertified runner must not be activated")

    program_reference = measurement_stack.get("program")
    target_reference = measurement_stack.get("target")
    policies = measurement_stack.get("policies")
    models = measurement_stack.get("models")
    if not isinstance(program_reference, dict):
        raise VerificationError("candidate has no program reference")
    if not isinstance(target_reference, dict):
        raise VerificationError("candidate has no target reference")
    if not isinstance(policies, dict):
        raise VerificationError("candidate has no policy references")
    if not isinstance(models, dict):
        raise VerificationError("candidate has no model references")

    program_manifest_path = _verify_pinned_asset(
        program_reference, "candidate program"
    )
    program_manifest = _load_json(program_manifest_path)
    program_documents, pinned_asset_count = _verify_program_manifest(
        program_manifest_path, program_manifest
    )
    documents.extend(program_documents)

    if program_manifest.get("programID") != program_reference.get("id"):
        raise VerificationError("candidate program ID does not match manifest")
    if program_manifest.get("programVersion") != program_reference.get("version"):
        raise VerificationError(
            "candidate program version does not match manifest"
        )

    target_path = _verify_pinned_asset(target_reference, "candidate target")
    target = _load_json(target_path)
    documents.append((str(target_path.relative_to(ROOT)), target))
    if target.get("targetID") != target_reference.get("id"):
        raise VerificationError("candidate target ID does not match manifest")
    if target.get("targetVersion") != target_reference.get("version"):
        raise VerificationError("candidate target version does not match manifest")
    if target.get("physicalDeviceRequired") is not True:
        raise VerificationError("Power iPhone target must require physical hardware")
    if target.get("simulatorAllowed") is not False:
        raise VerificationError("Power iPhone target must reject simulator evidence")

    for policy_name in ("runner", "intake", "ranking"):
        reference = policies.get(policy_name)
        if not isinstance(reference, dict):
            raise VerificationError(f"candidate has no {policy_name} policy")
        policy_path = _verify_pinned_asset(
            reference, f"candidate {policy_name} policy"
        )
        policy = _load_json(policy_path)
        documents.append((str(policy_path.relative_to(ROOT)), policy))
        if policy.get("policyVersion") != reference.get("version"):
            raise VerificationError(
                f"candidate {policy_name} policy version mismatch"
            )

    registry_reference = models.get("registry")
    cohort_reference = models.get("cohort")
    if not isinstance(registry_reference, dict):
        raise VerificationError("candidate has no model registry")
    if not isinstance(cohort_reference, dict):
        raise VerificationError("candidate has no model cohort")

    model_registry_path = _verify_pinned_asset(
        registry_reference, "candidate model registry"
    )
    model_registry = _load_json(model_registry_path)
    documents.append(
        (str(model_registry_path.relative_to(ROOT)), model_registry)
    )
    if model_registry.get("oldRankingStatusImported") is not False:
        raise VerificationError("candidate imports retired ranking status")
    cohort_path = _verify_pinned_asset(cohort_reference, "candidate model cohort")
    cohort = _load_json(cohort_path)
    documents.append((str(cohort_path.relative_to(ROOT)), cohort))
    if cohort.get("cohortID") != cohort_reference.get("id"):
        raise VerificationError("candidate cohort ID mismatch")
    if cohort.get("cohortVersion") != cohort_reference.get("version"):
        raise VerificationError("candidate cohort version mismatch")
    if cohort.get("rankingStatusImportedFromOlderMajor") is not False:
        raise VerificationError("candidate cohort imports retired ranking status")

    registered_model_count = _verify_model_registry(
        model_registry, cohort, documents
    )

    documents_by_path = dict(documents)
    contract_path = next(
        (
            reference["path"]
            for reference in program_manifest["assets"]
            if reference.get("role") == "program-contract"
        ),
        None,
    )
    if not isinstance(contract_path, str) or contract_path not in documents_by_path:
        raise VerificationError("program manifest has no readable contract")
    contract = documents_by_path[contract_path]
    if contract.get("programID") != program_reference.get("id"):
        raise VerificationError("program contract ID mismatch")
    if contract.get("programVersion") != program_reference.get("version"):
        raise VerificationError("program contract version mismatch")

    _verify_workload_fixtures(contract, documents_by_path)
    schema_count = _verify_schema_set(documents_by_path)
    _verify_workload_measurement_modes(contract, documents_by_path)
    _reject_legacy_references(documents)

    return {
        "status": "valid-migration-draft",
        "stackID": candidate.get("stackID"),
        "publicIntakeOpen": False,
        "program": (
            f"{program_reference.get('id')}@"
            f"{program_reference.get('version')}"
        ),
        "target": (
            f"{target_reference.get('id')}@"
            f"{target_reference.get('version')}"
        ),
        "pinnedProgramAssets": pinned_asset_count,
        "schemas": schema_count,
        "registeredModels": registered_model_count,
        "runnerComponents": runner_component_count,
        "runtimeAdapterImplemented": runtime_adapter_implemented,
        "appComponents": app_component_count,
        "appShellImplemented": True,
        "runnerCertified": False,
        "appReleased": False,
    }


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Verify and manage versioned benchmark product state."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser(
        "verify-power-candidate",
        help="verify the inactive clean-break Power candidate stack",
    )
    validate_parser = subparsers.add_parser(
        "validate-power-package",
        help="validate a Power 2.0 two-file package against trusted candidate state",
    )
    validate_parser.add_argument("path", type=Path)
    validate_parser.add_argument("--pr-author", required=True)
    validate_parser.add_argument("--evaluated-at", required=True)
    validate_parser.add_argument(
        "--validator-source-revision",
        required=True,
        help="trusted base Git revision (40- or 64-character hex)",
    )
    validate_parser.add_argument(
        "--accepted-result-digest",
        action="append",
        default=[],
        help="previously accepted result SHA-256; may be repeated",
    )
    return parser


def main() -> int:
    args = _build_parser().parse_args()
    exit_code = 0
    try:
        if args.command == "verify-power-candidate":
            summary = verify_power_candidate()
        elif args.command == "validate-power-package":
            try:
                from scripts.lib.power2.engine import validate_package
            except ModuleNotFoundError:
                from lib.power2.engine import validate_package

            summary = validate_package(
                args.path,
                evaluated_at=args.evaluated_at,
                validator_source_revision=args.validator_source_revision,
                pr_author=args.pr_author,
                accepted_result_digests=set(args.accepted_result_digest),
            )
            if summary["classification"] == "reject":
                exit_code = 1
        else:  # pragma: no cover - argparse prevents this branch.
            raise VerificationError(f"unsupported command: {args.command}")
    except (VerificationError, ValueError) as error:
        print(json.dumps({"status": "invalid", "error": str(error)}, indent=2))
        return 1

    print(json.dumps(summary, indent=2, sort_keys=True))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
