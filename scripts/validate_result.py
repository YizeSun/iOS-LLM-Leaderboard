#!/usr/bin/env python3
"""Validate a benchmark result JSON file."""

from __future__ import annotations

import json
import sys
from datetime import date
from pathlib import Path


REQUIRED_FIELDS = [
    "model_name",
    "provider",
    "task_id",
    "score",
    "evaluator",
    "date",
    "notes",
]


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as file:
        data = json.load(file)
    if not isinstance(data, dict):
        raise ValueError("top-level JSON value must be an object")
    return data


def validate(data: dict) -> list[str]:
    errors: list[str] = []

    for field in REQUIRED_FIELDS:
        if field not in data:
            errors.append(f"missing required field: {field}")
        elif data[field] in ("", None):
            errors.append(f"required field is empty: {field}")

    score = data.get("score")
    if "score" in data and not isinstance(score, (int, float)):
        errors.append("score must be a number")
    elif isinstance(score, (int, float)) and not 0 <= score <= 100:
        errors.append("score must be between 0 and 100")

    raw_date = data.get("date")
    if isinstance(raw_date, str):
        try:
            date.fromisoformat(raw_date)
        except ValueError:
            errors.append("date must use YYYY-MM-DD format")

    return errors


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate_result.py <result.json>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    try:
        data = load_json(path)
        errors = validate(data)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"{path}: invalid: {error}", file=sys.stderr)
        return 1

    if errors:
        for error in errors:
            print(f"{path}: {error}", file=sys.stderr)
        return 1

    print(f"{path}: valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
