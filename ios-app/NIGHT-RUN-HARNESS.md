# Guided Run in the Power Benchmark App Lab

## Branch boundary

This utility is developed and validated on
`codex/power-benchmark-app-lab`. The branch is an integration workspace and
must not be merged into `main` wholesale. Reusable App capabilities may be
extracted later into a focused App-only pull request after code review,
simulator verification, and physical-device validation. Guided Run evidence,
collection helpers, and unrelated branch changes remain branch-only.

The branch adds orchestration around the existing Power 1.0 reference runner:

- selected-model cache preparation;
- a persisted model/workload queue;
- nominal-thermal waiting between independent result cells;
- foreground and restart gates; and
- result-file bookkeeping and interrupted-session recovery.

Measurement is deliberately limited to one model per App process. The two
frozen Power workloads may run for that model, but selecting or loading another
model requires a full force-quit and relaunch. Releasing a Swift model object
is not accepted as proof that MLX, Metal, or process allocator state was reset.
Manual and Guided Run share one persisted model selection and cannot operate at
the same time. Guided Run executes the two frozen workloads sequentially for
that one model. This guarded branch build is App `0.11.0` build `14`;
previously collected
App-0.10.0 results retain their original App and source-commit identity.

It does not change Power workloads, protocol constants, result schemas,
measurement formulas, validators, model identities, or leaderboard logic.
Every result remains an unmodified `PowerResultBundle` written by the existing
runner to `Documents/PowerBenchmarkResults/`.

## Formal-result boundary

A Guided Run export is not formal merely because this harness created it. It
must pass the frozen Power validator, contributor declarations, integrity
checks, and maintainer review used by every other submission.

Because public intake authorizes exact App source commits, the result review
must additionally pin the exact App Lab commit and verify that the measured
behavior preserves the frozen Power contract. A source-review record may be
merged with a result package. Any reusable App implementation follows a
separate App-only review and is never introduced by merging this branch
wholesale.

## Operating sequence

1. Build this branch in Release with **Debug executable** disabled.
2. Connect and unlock the iPhone, then open the **Guided** tab.
3. Select exactly one model and tap **Prepare Selected Model**. The branch-only
   view reports artifact size, available iPhone storage, and the underlying
   Hugging Face error when a snapshot cannot be completed.
4. If anything downloads, fully close and relaunch the App.
5. Disconnect USB, MagSafe, and all charging. Keep Low Power Mode off.
6. Confirm at least 50% battery, detached debugger, Release build, and nominal
   thermal state.
7. Optionally record ambient temperature, case, placement, and thermal
   assistance. These are contribution notes only and never change the result.
8. Tap **Start Guided Run** and leave the App active on a ventilated hard
   surface. The harness disables idle sleep only while it is active.
9. Reconnect later and copy
   `Documents/PowerBenchmarkResults/` from the App data container.
10. To test another model, fully close and relaunch the App, then repeat from
   step 2. Do not reuse a process that loaded a different model.

Each workload result is written once by the existing runner. Sharing from the
App and collecting from the Mac both deliver that same frozen raw JSON file;
neither path recalculates or rewrites measurements.

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
