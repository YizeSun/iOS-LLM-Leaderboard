# Applications and certified runners

`apps/` is the MIT-licensed implementation plane for benchmark applications
and runner components.

Owner: App and runner maintainers.

Lifecycle:

- source modules evolve through ordinary code review;
- released App identities and runner component digests are retained;
- a measurement-affecting change requires a new runner certificate;
- UI-only changes may reuse an existing certificate when its support record
  permits that App release.

This root is necessary because the approved Target model is not limited to one
iPhone App. Shared shell, evidence, runner, Program, Target, and Runtime
components must remain separately reviewable as iPad and macOS Targets are
added. The current `ios-app/` remains the public Power 1.1 application during
migration. Nothing under `apps/` is public or certified until the Power 2
candidate is atomically released.

Current migration contents:

- `PowerRunnerKit/` — Power 2 evidence, Runner Core, text Program Module,
  Apple iPhone Target Adapter, and fixed-dependency MLX Runtime Adapter;
- `PowerAppKit/` — result persistence, two-file submission packaging, and
  direct GitHub contribution support. These non-measurement modules are kept
  outside the runner-certificate digest;
- `ios/` — the buildable, fail-closed candidate iOS App Shell, generated
  identity/catalog, and physical-iPhone-only certification smoke-test scheme.
  Candidate evidence stays local and cannot enter public intake; this is not a
  released or certified App target.
