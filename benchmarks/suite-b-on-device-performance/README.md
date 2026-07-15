# Suite B: On-device Performance

Suite B measures a pinned model artifact and runtime on a physical Apple device.
It is being redesigned around versioned workloads instead of one task per
metric.

## Status

- Framework v1 remains the repository-wide accepted format.
- Suite B Protocol v2 remains the design umbrella.
- `suite-b-power@1.0.0-rc.1` is the frozen, non-official source candidate.
- `suite-b-power@1.0.0` is the published Power release. It uses exact,
  hash-bound RC adoption without rerunning or mutating raw evidence.
- `suite-b-power@1.1.0-draft.1` is a non-official protocol draft. It requires
  the App to export every technically derivable metric and reserves behavior,
  metric, ranking, and recommendation decisions for the submission validator.
  Its independent validator and report contract are implemented as draft,
  hash-pinned assets. They change no Power 1.0 evidence or active ranking.
- `suite-b-power@1.1.0-rc.1` freezes the 1.1 result schema, validation report,
  semantic validator, ranking policy, fixtures, plans, and App 0.13.0 identity.
  It authorizes RC evidence collection only; ranking, publication, and tagging
  remain false until physical verification and final maintainer approval.
- `b-ux-001-short-interaction` and `b-pipe-001-sustained-generation` are the
  only Power 1.0 workload candidates.
- `b-pipe-002-input-length-sweep` and `b-ux-002-context-assistance` remain
  Experimental and are excluded from Power 1.0 eligibility and comparison.
- Historical `0.2.0-pilot` results remain non-official and require a new run
  against the F3/F4 contract; they are never promoted in place.
- F5 physical-device verification is complete for the declared three-model,
  one-runtime, one-device matrix.
- F6 submission and governance contracts are complete and merged.
- All six adopted physical-device results are Maintainer Reference evidence;
  five have an eligible primary metric and are active in the default
  workload-specific ranking.

## v2 Structure

| Category | Purpose | Draft workloads |
| --- | --- | --- |
| User experience | Express performance in recognizable app interactions | Short Interaction, Context Assistance |
| Pipeline | Diagnose scaling, sustained generation, memory, and thermal behavior | Sustained Generation, Input Length Sweep |

Every workload collects one compatible metric set. TTFT, prefill, decode,
memory, token intervals, thermal observations, and failures are measurements
from a run rather than separate tasks.

Read:

- [Suite B Protocol v2](protocol-v2.md)
- [Power 1.0 frozen protocol candidate](power-1.0-protocol.md)
- [Power 1.1 protocol draft](power-1.1-protocol.md)
- [Power 1.1 draft validation reason registry](power-1.1-validation-reasons.json)
- [Power 1.1 RC1 protocol](power-1.1-rc1-protocol.md)
- [Power 1.1 RC1 validation reason registry](power-1.1-rc1-validation-reasons.json)
- [Power 1.1 RC1 ranking policy](power-1.1-rc1-ranking-policy.json)
- [Power 1.0 environmental observation draft](power-1.0-environment-control.md)
- [Power 1.0 migration rules](power-1.0-migration.md)
- [Power 1.0 schema and validator freeze](power-1.0-schema-validator.md)
- [Power 1.0 RC1 submission guide](../../docs/power-benchmark-1.0-submission.md)
- [Power 1.0 governance](../../docs/power-benchmark-1.0-governance.md)
- [Power 1.0 finalization](../../docs/power-benchmark-1.0-finalization.md)
- [Power 1.0 official leaderboard](../../results/suite-b-power-1.0/LEADERBOARD.md)
- [Release history](releases/RELEASE-HISTORY.md)
- [Suite B Metric Definitions](metrics.md)
- [Framework v2 Architecture](../../methodology/benchmark-framework-v2.md)

Machine-readable workload manifests live in `workloads/`.

Validate them with:

```bash
python3 scripts/validate_suite_b_workload.py \
  benchmarks/suite-b-on-device-performance/workloads/*.json
```

## Legacy Drafts

The five `suite-b-on-device-performance-00x-*.md` files are Framework v1 metric
task drafts. They remain for migration history but are superseded by Protocol
v2 for future Suite B design. They must not be used for official submissions.
