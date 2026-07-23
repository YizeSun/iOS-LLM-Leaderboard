# Scripts

## Public entry point

The retained public command is:

```bash
python3 scripts/power.py submit RESULT.json --github HANDLE --accept-declarations
python3 scripts/power.py validate submissions/suite-b/power-1.1.0/draft/ID
python3 scripts/power.py preview
```

This command is SHA-256-pinned by the Power 1.1.1 release and therefore keeps
that release's App 0.13.0/App 0.16.0 compatibility boundary. App 0.18.0 direct
submission is handled by the configured App and the trusted Power 1.1.4 CI
adapters; do not modify `power.py` or advertise a second contributor CLI to
work around the frozen boundary.

## Current implementation tools

- `repoctl.py verify-power-candidate` verifies the inactive clean-break Power
  2.0 stack, every pinned candidate asset, fixture digest, schema set, Target,
  policy, model-cohort boundary, and the absence of active Power 1.1
  dependencies. It is a maintainer migration command and does not open intake.
- `repoctl.py validate-power-package` invokes the new dependency-free trusted
  validation engine with explicit PR author, evaluation timestamp, trusted
  source revision, and optional accepted-result digests. The candidate now has
  an active Runner certificate, but no App release or open intake, so public
  packages still correctly stop at those later gates.
- `generate_ios_app_release_identity.py` generates the App version/build
  xcconfig and Swift Power identity constants from
  `ios-app/Config/release-identity.json`; CI uses `--check` to reject drift.
- `generate_power_mlx_dependency_identity.py` verifies the direct MLX,
  Hugging Face, and tokenizer pins in
  `apps/PowerRunnerKit/Package.resolved`, then embeds the complete lock-file
  digest in the Runtime Adapter evidence identity.
- `generate_power_runner_component_manifest.py` hashes the separate Power 2
  evidence, Runner Core, text Program Module, iPhone Target Adapter, and MLX
  Runtime Adapter sources.
- `generate_power_release_candidates.py` binds those exact Runner components
  and the complete App component manifest into separate closed certification
  and release identities. It deterministically materializes the active Runner
  certificate only from the pinned passing Certification review; it never
  issues an App release or opens intake.
- `generate_power2_candidate_identity.py` generates candidate-only Swift
  identity from `products/power/candidate.json`. It is not compiled into the
  current Power 1.1 App and cannot open intake.
- `generate_power2_app_catalog.py` verifies the inactive candidate hash chain
  and generates the exact model, workload, and fixture catalog used only by
  the physical-iPhone `PowerCertification` smoke-test scheme. It does not
  issue a runner certificate, App release, or public submission permission.
- `review_power2_certification_result.py` applies the trusted Power 2 engine
  to one physical-iPhone Certification result using only the closed candidate
  identities. Its report is always non-publishable and non-ranking.
- `review_power2_app_release_result.py` applies the trusted engine to one exact
  Official App release-candidate result during the closed end-to-end
  rehearsal. Its report is also always non-publishable and non-ranking.
- `validate_suite_b_power_1_1_submission.py` validates the current two-file
  contribution package.
- `validate_suite_b_power_1_1_compatible_result.py` applies the versioned exact
  runner/runtime allowlist before reusing the frozen Power 1.1 validator.
- `validate_suite_b_power_1_1_final_result.py` derives final Power 1.1
  eligibility from adopted RC1 evidence and remains pinned and immutable.
- `generate_power_community_ranking.py` builds the live evidence dataset and
  Markdown views.
- `generate_ship_profiles.py` builds Ship evidence profiles.

Power 1.1.2 through 1.1.4 add isolated, version-suffixed adapters for trusted
validation, triage, and ranking. They load the frozen implementations without
changing their module globals or pinned bytes. They are release and CI assets,
not a parallel public contributor flow.

## Versioned and historical tools

Other scripts preserve release generation, pilot processing, Framework v1,
Power 1.0, RC validation, review records, and audit workflows. Some are pinned
by release manifests and must not be modified. They are implementation and
audit assets, not additional contributor entry points.

Before changing a release-specific script, check whether a manifest under
`benchmarks/**/releases/` pins its SHA-256. Create a new versioned asset instead
of altering a pinned file.

## Power 2.0 migration candidate

The current review command is:

```bash
python3 scripts/repoctl.py verify-power-candidate
python3 scripts/generate_power2_app_catalog.py --check
python3 scripts/generate_power_release_candidates.py --check
python3 scripts/repoctl.py validate-power-package PACKAGE \
  --pr-author HANDLE \
  --evaluated-at 2026-07-23T12:00:00Z \
  --validator-source-revision GIT_SHA
```

A successful result means only that the draft contract stack is internally
complete and independent from Power 1.1. It reports four exact rerun-candidate
models, an active source- and physical-evidence-bound Runner certificate, and
a closed App-release candidate, but deliberately no supported App release or
open intake.
The certification catalog check additionally proves that the App's closed
smoke-test catalog is a deterministic projection of those pinned assets; it
does not certify a run.
`scripts/power.py` remains the Power 1.1 public command until the atomic
cutover; it must not dispatch to both major versions.
