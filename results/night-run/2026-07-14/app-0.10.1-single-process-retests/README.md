# App 0.10.1 Single-process Retest Evidence

## Status

This is branch-only evidence retained on `codex/night-run-harness`. It was
exported by App `0.10.1` build `13` at source commit
`c8b1f7bc404e9b506aa5d7d5f9e7d8b7978271be` after the App began enforcing one
model identity per process.

This directory does not modify the frozen Power protocol, workloads, result
schema, validator, official Power 1.0 release, Ship profiles, or leaderboard
logic. The raw App exports are copied byte-for-byte. Their embedded
`officialResultEligible: false` values remain unchanged.

## Batch scope

- Device: iPhone 14 Pro Max (`iPhone15,3`)
- OS: iOS `26.5.2`, build `23F84`
- Runtime: MLX Swift LM `3.31.4` on Metal
- Models: 10
- Raw results: 21
- Structurally valid and protocol-conformant results: 21
- Queue snapshots retained: 9
- Failed results retained: 1

Each successful workload contains one warm-up attempt and five measured
attempts. All ten successful Pipeline results reached the fixed output-token
limit and have metric-eligible Pipeline TTFT, prefill, decode, and process
physical-footprint aggregates.

## Result summary

These are evidence summaries, not an authorized leaderboard.

| Model | Pipeline TTFT (ms) | Prefill (tok/s) | Decode (tok/s) | Physical footprint (MiB) | First-to-last decode change | Final thermal state | UX conformance |
| --- | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Qwen3 0.6B | 455.295 | 516.408 | 95.656 | 798.830 | -0.199% | nominal | fail |
| Qwen3 1.7B | 1718.859 | 136.735 | 27.561 | 1466.705 | -41.192% | serious | pass |
| Qwen3 4B | 4768.806 | 49.279 | 10.516 | 2389.362 | -26.931% | serious | pass |
| LFM2 1.2B | 839.394 | 295.495 | 64.589 | 1014.767 | -2.898% | fair | fail |
| Llama 3.2 1B Instruct | 571.236 | 462.310 | 60.246 | 1192.439 | 0.269% | fair | fail |
| Llama 3.2 3B Instruct | 3182.519 | 82.958 | 14.591 | 2524.049 | -38.649% | serious | fail |
| SmolLM3 3B | 6225.520 | 76.304 | 13.946 | 2549.502 | -41.793% | serious | fail |
| BitNet b1.58 2B 4T | 4707.802 | 49.706 | 33.560 | 1163.423 | -32.447% | serious | fail |
| EXAONE 4.0 1.2B | 934.297 | 267.654 | 49.356 | 1063.127 | -39.328% | serious | fail |
| Granite 3.3 2B Instruct | 2756.768 | 112.456 | 18.150 | 1964.393 | -35.594% | serious | fail |

`UX conformance` reports the five measured-attempt results under
`short-interaction-response-v1`. Qwen3 1.7B and Qwen3 4B have metric-eligible
UX summaries. The other eight successful UX results completed with model EOS
but failed response conformance, so their UX summary metrics correctly remain
`null`.

## Queue and failure retention

Nine queue snapshots each select exactly one model and identify the two
successful result filenames collected for that model.

The Qwen3 0.6B results were exported successfully, but its queue snapshot was
overwritten when the next LFM2 queue was selected before collection. No queue
file is fabricated for Qwen3 0.6B. Both raw Qwen files retain the exact App,
source, model, workload, device, and session identities and pass the frozen
Power validator; the missing queue snapshot remains an evidence-completeness
warning.

Granite emitted an additional Short Interaction result at
`2026-07-14T09:37:12Z`: its warm-up completed, then all five measured attempts
ended with `runtime_error`. The later queue-referenced Short Interaction rerun
completed. Both the failed result and the later completed result are retained;
the failed record is not hidden or replaced.

## Privacy review

The raw exports were scanned for user names, email addresses, Apple ID data,
UDID, serial number, vendor identifier, and local filesystem paths. No such
identifier was found. `device.displayName` contains only the public hardware
model, and generated text is limited to the frozen Short Interaction fixture.

This repository review does not assert contributor declarations on the
contributor's behalf. No two-file public-intake submission package is created
until the contributor explicitly confirms the seven required declarations
for this result batch.

## Publication boundary

App `0.10.1` build `13` is a branch-only orchestration source. Before any raw
result can enter the live community ranking, main must separately authorize
the exact source commit, the contributor must create hash-bound two-file
submission packages, and those packages must be merged through the normal
public-intake path. The immutable Power 1.0 release and tag are never rewritten.

See `SHA256SUMS` for the queue, raw-result, validation-report, and README
digests.
