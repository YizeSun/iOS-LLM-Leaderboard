# PowerRunnerKit

PowerRunnerKit is the candidate Power 2 measurement implementation. It is a
Swift package so the measurement-critical modules can be built and tested
without SwiftUI, GitHub OAuth, or the current Power 1.1 App target.

The package deliberately separates:

- `PowerEvidence` — immutable Power 2 evidence value types and deterministic
  JSON serialization;
- `PowerRunnerCore` — monotonic attempt lifecycle and failure preservation;
- `PowerTextProgram` — the text-generation Program contract adapter;
- `PowerAppleTarget` — iPhone environment capture and ranking admission;
- `PowerMLXRuntime` — exact MLX/Tokenizer dependency identity, immutable model
  revision loading, and token-stream adaptation.

The Runtime Adapter is implemented but the runner is not certified. No runner
certificate may be issued until the App integration and certification tests
pass and physical-device evidence is reviewed.

Run:

```bash
swift test --package-path apps/PowerRunnerKit
python3 scripts/generate_power_mlx_dependency_identity.py --check
python3 scripts/generate_power_runner_component_manifest.py --check
```
