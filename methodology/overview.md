# Methodology Overview

iOS-LLM-Leaderboard's public product architecture is Build, Power, and Ship.
Product Phase 1 is Power + Ship; Build is a Phase 2 Research Track. See the
[Product Architecture](../docs/product-architecture.md) for the authoritative
product mapping and priorities.

The methodology layer still retains five Framework v1 suite namespaces. These
are independent benchmark and evidence boundaries, not public product tracks
or equal implementation priorities:

- Suite A and Suite C preserve compatibility and historical Build research
  material; they are excluded from Phase 1.
- Suite B owns the canonical physical-device measurements used by Power.
- Suite D may contribute a later Power quality gate, but Pilot v0.1 executes no
  Suite D task.
- Suite E may contribute later Ship integration evidence, but Pilot v0.1
  executes no Suite E task or score. Its Ship view reuses the tested Suite B
  configuration.

The public leaderboard may emphasize model names for readability, while the
underlying evidence must retain the full evaluation-unit configuration.

Benchmark Framework v1 is defined in:

- [Benchmark Framework](benchmark-framework.md)
- [Benchmark Suites](benchmark-suites.md)
- [Benchmark Task Specification](benchmark-specification.md)
- [Benchmark Result Specification](benchmark-result-specification.md)
- [Benchmark Validation](benchmark-validation.md)

The retained Framework v1 namespaces are:

- Suite A: Swift Code Generation
- Suite B: On-device Performance
- Suite C: Xcode Integration
- Suite D: App Feature Intelligence
- Suite E: Runtime Evaluation

Suite namespaces should not be merged into a single score unless a future
methodology explicitly defines how to combine them. During migration,
independent suite-level reporting preserves evidence ownership and compatibility;
it does not define the product roadmap.

## Suite Boundaries

- Suite A covers Swift, SwiftUI, Apple API, and XCTest code generation tasks.
- Suite B covers measured local model performance on iPhone, iPad, and Mac devices.
- Suite C covers model behavior inside Xcode-oriented workflows such as completion, inline fixes, and refactoring.
- Suite D covers real app feature intelligence such as extraction, summarization, translation, safety behavior, and App Store-facing writing.
- Suite E covers runtime comparison across MLX Swift, llama.cpp, CoreML, LiteRT-LM, Apple Foundation Models, and future Apple runtime APIs.

Do not mix Swift code generation tasks, app feature intelligence tasks, Xcode workflow tasks, runtime measurements, and on-device performance results.

## Shared Scoring

Shared scoring conventions are documented in [scoring.md](scoring.md). Suite-specific methodology files define additional expectations for each suite.
