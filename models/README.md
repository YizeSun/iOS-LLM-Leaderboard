# Models

This directory documents how tested and recommended-for-testing models are
organized.

The machine-readable [Power test catalog](power-test-catalog.json) remains the
current Power 1.1 discovery surface until cutover.

The new [Power 2.0 artifact registry](registry.json) separately pins four exact
rerun candidates under `artifacts/`. Each manifest records the base-model
parameter count, artifact revision, repository byte count, weight SHA-256,
tokenizer SHA-256, format, quantization, license source, and revision-pinned
source URL. Selection for rerun does not import old evidence, compatibility,
recommendation, reproduction, or ranking status.

Future machine-readable model records should use a stable model artifact ID.
The public leaderboard may display a concise model name, while result evidence
references the exact artifact and tested profile.

Model metadata should include:

- model name
- provider or publisher
- model version
- parameter count when known
- context length when known
- license
- hosted or local availability
- supported runtimes
- quantization details for local runs

Do not add unverified performance claims to model metadata.

A Power 2.0 artifact may move beyond `rerun-candidate` only after the new
runtime adapter is certified and genuine Power 2.0 physical-device evidence is
submitted and accepted. Runtime registration is not evidence that a model
loads, fits in memory, completes either workload, or performs well on an
iPhone.
