# Night Run Harness Branch

## Branch boundary

This utility exists only on `codex/night-run-harness`. Its App source must
never be merged into `main`.

The branch adds orchestration around the existing Power 1.0 reference runner:

- batch cache preparation;
- a persisted model/workload queue;
- nominal-thermal waiting between independent result cells;
- foreground and restart gates; and
- result-file bookkeeping and interrupted-session recovery.

It does not change Power workloads, protocol constants, result schemas,
measurement formulas, validators, model identities, or leaderboard logic.
Every result remains an unmodified `PowerResultBundle` written by the existing
runner to `Documents/PowerBenchmarkResults/`.

## Formal-result boundary

A Night Run export is not formal merely because this harness created it. It
must pass the frozen Power validator, contributor declarations, integrity
checks, and maintainer review used by every other submission.

Because public intake authorizes exact App source commits, the result review
must additionally pin the exact Night Run commit and verify that its diff is
limited to orchestration. The source-review record may be merged with the
result package; this branch's App implementation must not be merged.

## Operating sequence

1. Build this branch in Release with **Debug executable** disabled.
2. Connect and unlock the iPhone, then open the **Night Run** tab.
3. Select models and tap **Prepare Selected Models**. The branch-only view
   reports selected artifact size, available iPhone storage, and the underlying
   Hugging Face error when a snapshot cannot be completed.
4. If anything downloads, fully close and relaunch the App.
5. Disconnect USB, MagSafe, and all charging. Keep Low Power Mode off.
6. Confirm at least 50% battery, detached debugger, Release build, and nominal
   thermal state.
7. Tap **Start Night Run** and leave the App active on a ventilated hard
   surface. The harness disables idle sleep only while it is active.
8. Reconnect the next morning and copy
   `Documents/PowerBenchmarkResults/` from the App data container.

From the repository root, the branch-only collection helper copies exactly the
filenames referenced by the saved queue and runs the frozen validator:

```sh
python3 scripts/night_run_collect.py \
  --device 'YOUR IPHONE NAME OR UDID' \
  --destination /path/to/night-run-evidence
```

This helper does not create a submission, publish a result, or update the
leaderboard.

The queue waits only for a non-nominal thermal state. Other Power admission
failures stop the queue rather than weakening the benchmark contract. If the
App leaves the foreground, the queue stops for review.
