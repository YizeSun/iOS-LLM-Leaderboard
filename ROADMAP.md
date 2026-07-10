# Roadmap

The roadmap follows one dependency chain:

> benchmark definition → official benchmark app → community evidence →
> validated leaderboard → developer integration recipes

Later phases must not be presented as complete before their dependencies are
validated.

## Phase 0: Vision and Architecture

- Define the Developer Assistance and Embedded Intelligence tracks.
- Define the Benchmark Specification, Community Evidence, and Developer
  Integration Guide layers.
- Keep the five suites independent.
- Confirm that the public leaderboard is model-centered while full
  configuration identity remains available as evidence.
- Define the role of the official community benchmark app.

## Phase 1: Framework v2 Design

- Separate workload, task, measurement mode, metric, and result.
- Define a common result envelope with suite-specific payloads.
- Define benchmark releases and migration rules.
- Define model artifact, runtime build, device profile, and inference
  configuration identities.
- Define result bundles and raw evidence requirements.
- Publish a Framework v1 to v2 migration map before changing stable IDs.

Framework v1 remains active until these rules are accepted and implemented.

Progress: the draft object model, Suite B workload categories, metric set,
pilot schemas, and migration direction are now documented. They remain draft.

## Phase 2: Suite B Complete Specification

- Replace evaluator-selected prompt ranges with versioned workloads.
- Define interactive, contextual, long-context, sustained-generation,
  model-load, and thermal-endurance tasks.
- Define TTFT, prefill, decode, memory, thermal, and failure metrics.
- Freeze token counting, cache, warm-up, run-count, aggregation, and environment
  rules.
- Define a pilot validation plan using one device, model, and runtime.

## Phase 3: Official iOS Benchmark App MVP

- Target physical iPhone devices first.
- Use a runtime-neutral adapter architecture.
- Implement MLX Swift as the first reference adapter.
- Run benchmark releases without network access during measured phases.
- Export a result bundle containing summary, raw runs, environment, and
  workload identity.
- Allow contributors to review all submitted fields.

Progress: the MLX physical-iPhone pilot now loads a pinned Qwen3 artifact,
runs one warm-up and five measured attempts, captures raw token timing, sampled
process footprint and thermal boundaries, and exports local JSON. It remains a
non-official instrumentation baseline.

## Phase 4: Validation and Repository Submission

- Add machine-readable JSON Schemas.
- Validate task, benchmark release, workload hash, and result structure.
- Recalculate supported metrics from raw event evidence.
- Add GitHub workflows and contribution templates.
- Support low-friction result submission from the benchmark app.
- Generate a pull request or bot-managed repository submission rather than
  writing directly to the default branch.

## Phase 5: Community Evidence

- Classify results as Draft, Community Submitted, Reproduced, Verified, or
  Maintainer Reference.
- Require independent reproduction for the default community ranking.
- Publish device-coverage gaps so contributors can see which iPhone models
  still need results.
- Preserve failed, OOM, interrupted, and unsupported runs as evidence.

## Phase 6: Suite B Leaderboard

- Generate separate views by device, workload, metric, benchmark release, and
  evidence level.
- Display model names prominently.
- Show a concise tested-profile label in the main view.
- Put full runtime, quantization, OS, and raw evidence on detail pages.
- Do not publish a global cross-suite score.

## Phase 7: Developer Integration Guide

- Add short Swift recipes for supported runtimes and model profiles.
- Cover installation, loading, generation, streaming, cancellation, context
  management, model distribution, and licensing.
- Publish recommended small-model views only when enough reproduced or verified
  results exist.
- Link each model recommendation to a tested reference profile.
- Avoid maintaining a separate full app for every recommended model.

## Phase 8: Expand the Remaining Suites

Recommended order:

1. Suite D minimum quality gate for recommended local models.
2. Suite E runtime integration scorecards that reuse Suite B measurements.
3. Suite A compile and test harnesses.
4. Suite C model-tool workflow harnesses.

## Current Immediate Work

- Keep current results explicitly non-official.
- Audit and freeze measurement boundaries before accepting Suite B results.
- Freeze `b-ux-001-short-interaction` prompt and visible-token policy.
- Make the App emit generation configuration, power evidence, workload identity,
  and versioned timing-boundary identity.
- Validate a second physical-iPhone run against recalculated raw evidence.
- Complete Suite B before expanding model or benchmark quantity.
