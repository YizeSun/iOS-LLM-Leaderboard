# Power 1.0 Draft Packages — Adopted RC.1 Contract

Each child directory must be named with its `submissionID` UUID and contain
exactly `submission.json` plus the unmodified `result.json` App export.

Public Draft packages remain `unreviewed`, never alter the leaderboard, and
must pass:

```bash
python3 scripts/validate_suite_b_power_submission.py \
  submissions/suite-b/power-1.0.0-rc.1/draft
```

Do not place Pilot wrappers, hand-authored performance numbers, screenshots,
logs, placeholder data, or personal identifiers here.
