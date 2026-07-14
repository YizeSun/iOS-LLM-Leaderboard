# BitNet b1.58 2B 4T Night Run Evidence

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

- Model artifact: `mlx-community/bitnet-b1.58-2B-4T-4bit`
- Artifact revision: `f4c3737ce9cd34ffe48a01647e779a68f97f08b1`
- Base model: `microsoft/bitnet-b1.58-2B-4T`
- Quantization: `4-bit`
- Runtime: MLX Swift on Metal
- Device: iPhone 14 Pro Max (`iPhone15,3`)
- OS: iOS `26.5.2`, build `23F84`
- Environment captured by the App: Release, debugger detached, Low Power Mode
  off, battery unplugged at approximately 70%, session thermal state
  `nominal` at both ends for Short Interaction and `nominal` to `fair` for
  Sustained Generation

## Results

### Short Interaction

Result ID: `DC2A424C-A52B-4502-92CC-1F6C1B932F98`

The warm-up and all five measured attempts completed with model EOS. All six
responses failed `short-interaction-response-v1`, so every UX performance
metric is correctly `null`. The result is structurally valid and protocol
conformant, but it supplies no metric-eligible Short Interaction value.

### Sustained Generation

Result ID: `6AF5C7FC-B1BE-452E-B980-A1C8F567CE88`

The warm-up and all five measured attempts completed at the output-token
limit. All five measured attempts are eligible for Pipeline TTFT, prefill,
decode, and process-footprint aggregation.

| Metric | Aggregate |
| --- | ---: |
| Median Pipeline TTFT | 4709.42025 ms |
| Median prefill throughput | 49.68879727894157 tok/s |
| Median decode throughput | 36.03303990093366 tok/s |
| Median process physical footprint | 2923.596321105957 MiB |
| First-to-last decode change | -28.492658452024333% |

The Pipeline session changed from `nominal` to `fair`; the transition was
observed during measured attempt four and the final measured attempt began and
ended at `fair`. These values are evidence for this exact execution identity
only and do not establish broad thermal or device behavior.

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

