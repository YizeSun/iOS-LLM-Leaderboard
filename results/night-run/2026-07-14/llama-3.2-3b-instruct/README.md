# Llama 3.2 3B Instruct Night Run Evidence

## Status

This is branch-only evidence retained on `codex/night-run-harness`. It was
exported by App `0.10.0` build `12` at source commit
`07a79186a701afee93d3ae8d8dd77a7b50b702ae` and collected with
`scripts/night_run_collect.py`.

The collector copied the raw App exports byte-for-byte, selected the two files
named by `night-run-queue.json`, and ran the frozen Power result validator. It
did not create a submission, grant an evidence level, update a leaderboard, or
modify either raw result.

## Execution identity

- Model artifact: `mlx-community/Llama-3.2-3B-Instruct-4bit`
- Artifact revision: `7f0dc925e0d0afb0322d96f9255cfddf2ba5636e`
- Base model: `meta-llama/Llama-3.2-3B-Instruct`
- Quantization: `4-bit`
- Runtime: MLX Swift on Metal
- Device: iPhone 14 Pro Max (`iPhone15,3`)
- OS: iOS `26.5.2`, build `23F84`
- Environment captured by the App: Release, debugger detached, Low Power Mode
  off, battery unplugged at approximately 70%, session thermal state
  `nominal` at both ends for Short Interaction and `nominal` to `serious` for
  Sustained Generation

## Results

### Short Interaction

Result ID: `F18D722D-1240-410B-A318-4F039C43077E`

The warm-up and all five measured attempts completed with model EOS. All six
responses failed `short-interaction-response-v1`, so every UX performance
metric is correctly `null`. The result is structurally valid and protocol
conformant, but it supplies no metric-eligible Short Interaction value.

### Sustained Generation

Result ID: `F442681C-27AF-4460-A292-FBFB753FE818`

The warm-up and all five measured attempts completed at the output-token
limit. All five measured attempts are eligible for Pipeline TTFT, prefill,
decode, and process-footprint aggregation.

| Metric | Aggregate |
| --- | ---: |
| Median Pipeline TTFT | 2858.951625 ms |
| Median prefill throughput | 92.34669919825404 tok/s |
| Median decode throughput | 17.85738716686734 tok/s |
| Median process physical footprint | 2533.143035888672 MiB |
| First-to-last decode change | -33.18837598397364% |

The Pipeline session changed from `nominal` to `fair` during measured attempt
zero and from `fair` to `serious` during measured attempt one. The remaining
measured attempts began and ended at `serious`. The protocol stops later work
at `critical`, not `serious`, so these completed attempts remain valid evidence.
These values apply only to this exact execution identity and do not establish
broad thermal or device behavior.

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

