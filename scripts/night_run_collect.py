#!/usr/bin/env python3
"""Pull one Night Run queue from an iPhone and validate its raw Power results."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUNDLE_ID = "org.iosllmleaderboard.benchmark"
VALIDATOR = ROOT / "scripts/validate_suite_b_power_result.py"


def copy_from_device(
    *, device: str, source: str, destination: Path
) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "xcrun",
            "devicectl",
            "device",
            "copy",
            "from",
            "--device",
            device,
            "--source",
            source,
            "--destination",
            str(destination),
            "--domain-type",
            "appDataContainer",
            "--domain-identifier",
            BUNDLE_ID,
        ],
        check=True,
    )


def find_result(root: Path, filename: str) -> Path | None:
    matches = list(root.rglob(filename))
    return matches[0] if len(matches) == 1 else None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--device",
        required=True,
        help="Device name, UDID, or CoreDevice identifier accepted by devicectl.",
    )
    parser.add_argument(
        "--destination",
        required=True,
        type=Path,
        help="Empty or new local directory for the evidence copy.",
    )
    args = parser.parse_args(argv)

    destination = args.destination.resolve()
    destination.mkdir(parents=True, exist_ok=True)
    queue_path = destination / "night-run-queue.json"
    results_root = destination / "PowerBenchmarkResults"

    copy_from_device(
        device=args.device,
        source="Library/Application Support/NightRunHarness/queue.json",
        destination=queue_path,
    )
    copy_from_device(
        device=args.device,
        source="Documents/PowerBenchmarkResults",
        destination=results_root,
    )

    queue = json.loads(queue_path.read_text())
    filenames = [
        cell["resultFilename"]
        for cell in queue.get("cells", [])
        if cell.get("status") == "completed" and cell.get("resultFilename")
    ]
    reports = destination / "validation"
    reports.mkdir(exist_ok=True)

    invalid: list[str] = []
    missing: list[str] = []
    for filename in filenames:
        result = find_result(results_root, filename)
        if result is None:
            missing.append(filename)
            continue
        report = reports / f"{result.stem}.validation.json"
        completed = subprocess.run(
            [
                sys.executable,
                str(VALIDATOR),
                str(result),
                "--output",
                str(report),
            ],
            check=False,
        )
        if completed.returncode != 0:
            invalid.append(filename)

    print(f"queue results: {len(filenames)}")
    print(f"validated: {len(filenames) - len(missing) - len(invalid)}")
    if missing:
        print("missing:")
        for filename in missing:
            print(f"  {filename}")
    if invalid:
        print("invalid:")
        for filename in invalid:
            print(f"  {filename}")
    print(f"evidence directory: {destination}")
    return 1 if missing or invalid else 0


if __name__ == "__main__":
    raise SystemExit(main())
