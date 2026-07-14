# Gemma 3 1B IT Single-model Retest Evidence

## Status

This is branch-only evidence retained on `codex/night-run-harness`. It was
exported by App `0.10.0` build `12` at source commit
`07a79186a701afee93d3ae8d8dd77a7b50b702ae` and collected with
`scripts/night_run_collect.py`.

The saved queue selected only `gemma-3-1b-it-qat-4bit`. The collector copied
the raw App exports byte-for-byte, selected the two filenames named by the
queue, and ran the frozen Power result validator. It did not create a
submission, grant an evidence level, update a leaderboard, or modify either
raw result.

## Execution identity

- Model artifact: `mlx-community/gemma-3-1b-it-qat-4bit`
- Artifact revision: `15fed4eafb456c6fcb2a1165f19ac609670ed14b`
- Base model: `google/gemma-3-1b-it`
- Quantization: `4-bit`
- Runtime: MLX Swift on Metal
- Device: iPhone 14 Pro Max (`iPhone15,3`)
- OS: iOS `26.5.2`, build `23F84`
- Environment captured by the App: Release, debugger detached, Low Power Mode
  off, battery unplugged at approximately 65%, session thermal state
  `nominal` at both ends for Short Interaction and `nominal` to `serious` for
  Sustained Generation

## Results

### Short Interaction

Result ID: `7F1BDE49-2104-4D07-BF65-3D6CC423C644`

The warm-up and all five measured attempts completed with model EOS. All six
responses failed `short-interaction-response-v1`, so every UX performance
metric is correctly `null`. The result is structurally valid and protocol
conformant, but it supplies no metric-eligible Short Interaction value.

### Sustained Generation

Result ID: `0E125819-EC39-47B5-96A8-0A2D33654099`

The warm-up and all five measured attempts completed at the output-token
limit. All five measured attempts are eligible for Pipeline TTFT, prefill,
decode, and process-footprint aggregation.

| Metric | Aggregate |
| --- | ---: |
| Median Pipeline TTFT | 449.997958 ms |
| Median prefill throughput | 538.0299978714244 tok/s |
| Median decode throughput | 65.21407490257803 tok/s |
| Median process physical footprint | 1165.611099243164 MiB |
| First-to-last decode change | -38.22997827342879% |

The Pipeline session changed from `nominal` to `fair` during measured attempt
two and from `fair` to `serious` during measured attempt four. The protocol
stops later work at `critical`, not `serious`, so these completed attempts
remain valid evidence. These values apply only to this exact execution identity
and do not establish broad thermal or device behavior.

## Validation and review boundary

Both result files report `validWithWarnings`, with structural validity and
protocol conformance passing. The Pipeline metrics are eligible; the Short
Interaction metrics are not. The evidence level remains `unreviewed`, and no
ranking or publication decision is made in this branch.

Ambient temperature, support surface, case state, and external thermal
assistance are not fields in these raw result files. No separate
contemporaneous environmental declaration is included here, so this bundle
must not be represented as conforming to a later environmental-control
addendum without additional evidence.

See `SHA256SUMS` for the immutable queue, raw-result, and validation-report
digests.

