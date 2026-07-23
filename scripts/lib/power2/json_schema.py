"""Small dependency-free JSON Schema 2020-12 evaluator.

This implements only the vocabulary used by the Power 2.0 schemas. Unsupported
keywords are ignored as annotations, matching JSON Schema behavior for unknown
vocabularies. The repository tests exercise every supported keyword.
"""

from __future__ import annotations

import json
import re
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any


class SchemaResolutionError(ValueError):
    """Raised when a local schema reference cannot be resolved safely."""


class SchemaStore:
    def __init__(self, repository_root: Path):
        self.repository_root = repository_root.resolve()
        self._cache: dict[Path, dict[str, Any]] = {}

    def load(self, path: Path) -> dict[str, Any]:
        resolved = path.resolve()
        try:
            resolved.relative_to(self.repository_root)
        except ValueError as error:
            raise SchemaResolutionError(
                f"schema escapes repository root: {path}"
            ) from error
        if resolved not in self._cache:
            value = json.loads(resolved.read_text(encoding="utf-8"))
            if not isinstance(value, dict):
                raise SchemaResolutionError(
                    f"schema is not an object: {resolved}"
                )
            self._cache[resolved] = value
        return self._cache[resolved]

    def resolve(
        self,
        reference: str,
        root_schema: dict[str, Any],
        schema_path: Path,
    ) -> tuple[dict[str, Any], dict[str, Any], Path]:
        document_reference, separator, fragment = reference.partition("#")
        if document_reference:
            referenced_path = (schema_path.parent / document_reference).resolve()
            referenced_root = self.load(referenced_path)
            resolved_schema = referenced_root
            resolved_path = referenced_path
        else:
            referenced_root = root_schema
            resolved_schema = root_schema
            resolved_path = schema_path

        if separator and fragment:
            if not fragment.startswith("/"):
                raise SchemaResolutionError(
                    f"unsupported schema fragment: {reference}"
                )
            for encoded_part in fragment[1:].split("/"):
                part = encoded_part.replace("~1", "/").replace("~0", "~")
                if not isinstance(resolved_schema, dict) or part not in resolved_schema:
                    raise SchemaResolutionError(
                        f"unresolved schema reference: {reference}"
                    )
                resolved_schema = resolved_schema[part]

        if not isinstance(resolved_schema, dict):
            raise SchemaResolutionError(
                f"schema reference is not an object: {reference}"
            )
        return resolved_schema, referenced_root, resolved_path


def validate(
    instance: Any,
    schema_path: Path,
    repository_root: Path,
) -> list[str]:
    store = SchemaStore(repository_root)
    root_schema = store.load(schema_path)
    errors: list[str] = []
    _validate(
        instance,
        root_schema,
        root_schema,
        schema_path.resolve(),
        "$",
        store,
        errors,
    )
    return errors


def _type_matches(instance: Any, expected: str) -> bool:
    if expected == "null":
        return instance is None
    if expected == "boolean":
        return isinstance(instance, bool)
    if expected == "integer":
        return isinstance(instance, int) and not isinstance(instance, bool)
    if expected == "number":
        return isinstance(instance, (int, float)) and not isinstance(instance, bool)
    if expected == "string":
        return isinstance(instance, str)
    if expected == "array":
        return isinstance(instance, list)
    if expected == "object":
        return isinstance(instance, dict)
    return False


def _schema_matches(
    instance: Any,
    schema: dict[str, Any],
    root_schema: dict[str, Any],
    schema_path: Path,
    path: str,
    store: SchemaStore,
) -> bool:
    probe: list[str] = []
    _validate(
        instance,
        schema,
        root_schema,
        schema_path,
        path,
        store,
        probe,
    )
    return not probe


def _validate_format(instance: str, format_name: str) -> bool:
    if format_name == "uuid":
        try:
            return str(uuid.UUID(instance)) == instance.lower()
        except (ValueError, AttributeError):
            return False
    if format_name == "date-time":
        try:
            normalized = instance[:-1] + "+00:00" if instance.endswith("Z") else instance
            parsed = datetime.fromisoformat(normalized)
            return parsed.tzinfo is not None
        except (ValueError, TypeError):
            return False
    return True


def _validate(
    instance: Any,
    schema: dict[str, Any],
    root_schema: dict[str, Any],
    schema_path: Path,
    path: str,
    store: SchemaStore,
    errors: list[str],
) -> None:
    reference = schema.get("$ref")
    if isinstance(reference, str):
        try:
            resolved, referenced_root, referenced_path = store.resolve(
                reference, root_schema, schema_path
            )
        except (OSError, json.JSONDecodeError, SchemaResolutionError) as error:
            errors.append(f"{path}: {error}")
            return
        _validate(
            instance,
            resolved,
            referenced_root,
            referenced_path,
            path,
            store,
            errors,
        )
        return

    for child_schema in schema.get("allOf", []):
        if isinstance(child_schema, dict):
            _validate(
                instance,
                child_schema,
                root_schema,
                schema_path,
                path,
                store,
                errors,
            )

    one_of = schema.get("oneOf")
    if isinstance(one_of, list):
        matches = sum(
            1
            for child_schema in one_of
            if isinstance(child_schema, dict)
            and _schema_matches(
                instance,
                child_schema,
                root_schema,
                schema_path,
                path,
                store,
            )
        )
        if matches != 1:
            errors.append(f"{path}: expected exactly one oneOf branch, found {matches}")

    condition = schema.get("if")
    if isinstance(condition, dict):
        branch_name = (
            "then"
            if _schema_matches(
                instance,
                condition,
                root_schema,
                schema_path,
                path,
                store,
            )
            else "else"
        )
        branch = schema.get(branch_name)
        if isinstance(branch, dict):
            _validate(
                instance,
                branch,
                root_schema,
                schema_path,
                path,
                store,
                errors,
            )

    expected_type = schema.get("type")
    if isinstance(expected_type, str):
        accepted_types = [expected_type]
    elif isinstance(expected_type, list):
        accepted_types = [
            value for value in expected_type if isinstance(value, str)
        ]
    else:
        accepted_types = []
    if accepted_types and not any(
        _type_matches(instance, expected) for expected in accepted_types
    ):
        errors.append(
            f"{path}: expected type {' or '.join(accepted_types)}, "
            f"found {type(instance).__name__}"
        )
        return

    if "const" in schema and instance != schema["const"]:
        errors.append(f"{path}: value does not match const")
    enum = schema.get("enum")
    if isinstance(enum, list) and instance not in enum:
        errors.append(f"{path}: value is not in enum")

    if isinstance(instance, str):
        min_length = schema.get("minLength")
        if isinstance(min_length, int) and len(instance) < min_length:
            errors.append(f"{path}: string is shorter than {min_length}")
        pattern = schema.get("pattern")
        if isinstance(pattern, str) and re.search(pattern, instance) is None:
            errors.append(f"{path}: string does not match pattern {pattern!r}")
        format_name = schema.get("format")
        if isinstance(format_name, str) and not _validate_format(
            instance, format_name
        ):
            errors.append(f"{path}: invalid {format_name}")

    if isinstance(instance, (int, float)) and not isinstance(instance, bool):
        minimum = schema.get("minimum")
        maximum = schema.get("maximum")
        if isinstance(minimum, (int, float)) and instance < minimum:
            errors.append(f"{path}: value is below minimum {minimum}")
        if isinstance(maximum, (int, float)) and instance > maximum:
            errors.append(f"{path}: value is above maximum {maximum}")

    if isinstance(instance, dict):
        required = schema.get("required")
        if isinstance(required, list):
            for key in required:
                if isinstance(key, str) and key not in instance:
                    errors.append(f"{path}: missing required property {key!r}")

        properties = schema.get("properties")
        known_properties = properties if isinstance(properties, dict) else {}
        for key, child_schema in known_properties.items():
            if key in instance and isinstance(child_schema, dict):
                _validate(
                    instance[key],
                    child_schema,
                    root_schema,
                    schema_path,
                    f"{path}.{key}",
                    store,
                    errors,
                )

        additional = schema.get("additionalProperties", True)
        for key, value in instance.items():
            if key in known_properties:
                continue
            if additional is False:
                errors.append(f"{path}: unexpected property {key!r}")
            elif isinstance(additional, dict):
                _validate(
                    value,
                    additional,
                    root_schema,
                    schema_path,
                    f"{path}.{key}",
                    store,
                    errors,
                )

    if isinstance(instance, list):
        min_items = schema.get("minItems")
        max_items = schema.get("maxItems")
        if isinstance(min_items, int) and len(instance) < min_items:
            errors.append(f"{path}: array has fewer than {min_items} items")
        if isinstance(max_items, int) and len(instance) > max_items:
            errors.append(f"{path}: array has more than {max_items} items")
        if schema.get("uniqueItems") is True:
            serialized = [
                json.dumps(item, sort_keys=True, separators=(",", ":"))
                for item in instance
            ]
            if len(serialized) != len(set(serialized)):
                errors.append(f"{path}: array items are not unique")

        prefix_items = schema.get("prefixItems")
        prefix_count = 0
        if isinstance(prefix_items, list):
            prefix_count = len(prefix_items)
            for index, child_schema in enumerate(prefix_items):
                if index >= len(instance):
                    break
                if isinstance(child_schema, dict):
                    _validate(
                        instance[index],
                        child_schema,
                        root_schema,
                        schema_path,
                        f"{path}[{index}]",
                        store,
                        errors,
                    )

        item_schema = schema.get("items")
        remaining_start = prefix_count if isinstance(prefix_items, list) else 0
        if item_schema is False and len(instance) > remaining_start:
            errors.append(
                f"{path}: array contains items beyond the allowed prefix"
            )
        elif isinstance(item_schema, dict):
            for index in range(remaining_start, len(instance)):
                _validate(
                    instance[index],
                    item_schema,
                    root_schema,
                    schema_path,
                    f"{path}[{index}]",
                    store,
                    errors,
                )
