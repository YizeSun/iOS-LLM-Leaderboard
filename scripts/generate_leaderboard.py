#!/usr/bin/env python3
"""Generate a Markdown leaderboard from JSON files in results/raw."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RAW_RESULTS = ROOT / "results" / "raw"
OUTPUT = ROOT / "results" / "LEADERBOARD.md"


def load_results() -> list[dict]:
    results: list[dict] = []
    for path in sorted(RAW_RESULTS.glob("*.json")):
        with path.open("r", encoding="utf-8") as file:
            data = json.load(file)
        if isinstance(data, dict):
            data["_source"] = path.relative_to(ROOT).as_posix()
            results.append(data)
    return results


def format_score(value: object) -> str:
    if isinstance(value, (int, float)):
        return f"{value:.2f}"
    return ""


def render(results: list[dict]) -> str:
    lines = [
        "# Leaderboard",
        "",
        "This file is generated from JSON files in `results/raw/`.",
        "",
    ]

    if not results:
        lines.extend(
            [
                "No official results have been submitted yet.",
                "",
                "The table below is placeholder/demo data only and must not be interpreted as a ranking.",
                "",
                "| Rank | Model | Provider | Task | Score | Evaluator | Date | Notes |",
                "| --- | --- | --- | --- | ---: | --- | --- | --- |",
                "| - | DemoModel-A | Demo Provider | demo-task | 0.00 | Demo Evaluator | 2026-07-08 | Placeholder only |",
                "",
            ]
        )
        return "\n".join(lines)

    ranked = sorted(results, key=lambda item: item.get("score", 0), reverse=True)
    lines.extend(
        [
            "| Rank | Model | Provider | Task | Score | Evaluator | Date | Notes |",
            "| ---: | --- | --- | --- | ---: | --- | --- | --- |",
        ]
    )

    for index, item in enumerate(ranked, start=1):
        lines.append(
            "| {rank} | {model} | {provider} | {task} | {score} | {evaluator} | {date} | {notes} |".format(
                rank=index,
                model=item.get("model_name", ""),
                provider=item.get("provider", ""),
                task=item.get("task_id", ""),
                score=format_score(item.get("score")),
                evaluator=item.get("evaluator", ""),
                date=item.get("date", ""),
                notes=str(item.get("notes", "")).replace("|", "\\|"),
            )
        )

    lines.append("")
    return "\n".join(lines)


def main() -> int:
    OUTPUT.write_text(render(load_results()), encoding="utf-8")
    print(f"wrote {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
