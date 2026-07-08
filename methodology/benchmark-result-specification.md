# Benchmark Result Specification

Benchmark results should be stored as JSON files under `results/raw/`.

Official leaderboard generation should only use validated result files. Demo-placeholder results must not be used in official leaderboard generation.

## Canonical Result JSON

```json
{
  "schema_version": "1.0",
  "result_id": "2026-07-09-suite-a-swift-codegen-001-gpt-example",
  "task": {
    "task_id": "suite-a-swift-codegen-001",
    "task_version": "1.0",
    "suite": "Suite A: Swift Code Generation",
    "category": "SwiftUI",
    "subcategory": "List Deletion"
  },
  "model": {
    "model_name": "Example Model",
    "provider": "Example Provider",
    "model_version": "unknown",
    "access_type": "api",
    "parameter_size": null,
    "quantization": null
  },
  "runtime": {
    "runtime_name": null,
    "runtime_version": null,
    "backend": null,
    "model_format": null
  },
  "device": {
    "device_name": null,
    "chip": null,
    "memory_gb": null,
    "os_name": null,
    "os_version": null
  },
  "execution": {
    "date": "YYYY-MM-DD",
    "evaluator": "name-or-github-handle",
    "run_type": "manual",
    "temperature": null,
    "seed": null,
    "prompt_tokens": null,
    "output_tokens": null,
    "notes": ""
  },
  "output": {
    "raw_output_path": null,
    "summary": "",
    "structured_output": null
  },
  "evaluation": {
    "score": null,
    "max_score": 10,
    "passed": null,
    "automatic_checks": [],
    "manual_review": [],
    "failure_reasons": [],
    "reviewer_notes": ""
  },
  "metrics": {
    "ttft_ms": null,
    "prefill_tokens_per_second": null,
    "decode_tokens_per_second": null,
    "peak_memory_mb": null,
    "energy_joules": null,
    "thermal_state": null,
    "p50_token_interval_ms": null,
    "p95_token_interval_ms": null,
    "p99_token_interval_ms": null
  },
  "provenance": {
    "source": "manual-submission",
    "commit_sha": null,
    "raw_artifact_paths": [],
    "reproduction_notes": ""
  },
  "license_confirmation": {
    "contributor_agrees_to_repo_license": true
  }
}
```

## Required Result Fields

Every result must include:

```text
schema_version
result_id
task.task_id
task.task_version
task.suite
model.model_name
model.provider
execution.date
execution.evaluator
evaluation.score
evaluation.max_score
evaluation.passed
license_confirmation.contributor_agrees_to_repo_license
```

If a field is not applicable, use `null`. Do not omit required fields.

## result_id Format

Suggested format:

```text
YYYY-MM-DD-task-id-model-name-short-run-id
```

Example:

```text
2026-07-09-suite-a-swift-codegen-001-gpt-example
```

## Allowed model.access_type Values

```text
api
local
xcode
hosted
unknown
```

## Allowed execution.run_type Values

```text
manual
scripted
app-export
ci
unknown
```

## Allowed provenance.source Values

```text
manual-submission
benchmark-app
maintainer-run
ci
imported
demo-placeholder
```

Demo placeholder results must not be used in official leaderboard generation.

## Suite-Specific Result Requirements

### Suite A

Recommended:

- `compile_success` check
- `unit_tests` check if applicable
- manual review for Swift idiomatic quality
- manual review for architecture/readability

### Suite B

Required:

- runtime metadata
- device metadata
- `metrics.ttft_ms`
- `metrics.decode_tokens_per_second`
- `metrics.peak_memory_mb`

Recommended:

- `metrics.prefill_tokens_per_second`
- `metrics.energy_joules`
- `metrics.thermal_state`
- `metrics.p50_token_interval_ms`
- `metrics.p95_token_interval_ms`
- `metrics.p99_token_interval_ms`

### Suite C

Recommended:

- device metadata
- Xcode or IDE environment in `execution.notes` or `provenance`
- `output.summary`
- `evaluation.manual_review`

Useful criteria:

- completion usefulness
- fix correctness
- compile success after fix
- developer workflow usefulness

### Suite D

Recommended:

- `output.structured_output`
- `evaluation.automatic_checks`
- `evaluation.manual_review`

Useful criteria:

- schema validity
- extraction accuracy
- translation quality
- summarization fidelity
- safety behavior

### Suite E

Required:

- `runtime.runtime_name`
- `runtime.runtime_version`
- `runtime.backend`
- `runtime.model_format`
- `device.device_name`
- `device.os_version`
- metrics

Suite E must clearly state whether it evaluates:

- a runtime
- a model
- a model-runtime pair
