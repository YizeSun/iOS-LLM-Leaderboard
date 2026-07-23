# PowerAppKit

PowerAppKit is the non-measurement support layer for the candidate Power 2
App. It is MIT licensed and deliberately separate from the runner certificate
digest.

- `PowerResultsStore` writes the encoded evidence once and later returns the
  exact same bytes.
- `PowerSubmissionKit` creates the two-file contribution package without
  rewriting `result.json`.
- `PowerGitHubSubmission` performs Device Flow and opens a result-only pull
  request from a contributor fork.

The GitHub client does not synchronize the fork's default branch. It creates a
fresh submission branch from the exact upstream default-branch commit instead,
so a public-repository OAuth token does not need permission to update workflow
files merely because a fork is behind.

This package is migration-draft code. It is not a released App or an open
submission route.
