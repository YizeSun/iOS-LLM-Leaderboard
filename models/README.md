# Models

This directory documents how tested and recommended-for-testing models are
organized.

The machine-readable [Power test catalog](power-test-catalog.json) separates
three evidence states:

- `models`: pinned 4-bit artifacts registered by the locked MLX Swift LM
  runtime and selectable in the candidate Reference App;
- `compatibilityReview`: small pinned artifacts with one or more concrete
  blockers to the frozen Power 1.0 App path; and
- `reviewedIneligible`: completed reviews retained for traceability but not
  displayed as recommended tests because they exceed the initial device-scale
  boundary or lack a practical App artifact.

Only the first two groups are rendered in the public Models view. Catalog rows
are discovery and contribution targets, never leaderboard rows, compatibility
proof, or performance claims. See the
[2026-07-13 model audit](power-model-audit-2026-07-13.md) for the selection
evidence and exclusions.

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

An artifact may move out of `untested` only after a genuine App export is
submitted and accepted. Runtime registry support is not evidence that a model
loads, fits in memory, completes either workload, or performs well on an
iPhone.
