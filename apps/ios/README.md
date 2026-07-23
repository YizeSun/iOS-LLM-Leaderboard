# Power 2 iOS App candidate

This directory now contains the clean Power 2 candidate App Shell. It has
separate Test and Results tabs, consumes the generated candidate identity, and
uses `PowerAppKit` for exact-byte result storage. It links the complete
candidate `PowerRunnerKit` implementation so generic iOS Release builds verify
the real dependency graph.

Debug and Release deliberately disable measurement and GitHub submission
because there is no released App identity, runner certificate, active Power
pointer, or open public intake. This fail-closed state prevents a migration
build from producing evidence that looks official.

The separate `PowerCertification` scheme is a maintainer-only physical-iPhone
smoke-test path. It executes the exact models, workloads, Runner, Program, and
Target pinned by the inactive candidate and saves a candidate evidence envelope
locally. It is compiled only for `iphoneos`, requires the exact checked-out Git
revision at build time, and cannot submit or rank the resulting evidence:

```bash
xcodebuild \
  -project apps/ios/PowerBenchmarkApp.xcodeproj \
  -scheme PowerCertification \
  -configuration Certification \
  -destination 'platform=iOS,name=YOUR_IPHONE' \
  POWER_SOURCE_REVISION="$(git rev-parse HEAD)" \
  build
```

Do not archive, distribute, or describe this build as a released benchmark
App. Its `2.0.0-certification` identity and candidate certificate ID exist only
to bind pre-release physical-device review to exact source.

The current `ios-app/` remains the Power 1.1 public App until the atomic
clean-break cutover. No Power 1.1 result is imported, converted, displayed, or
submitted by this candidate.

`Power2CandidateIdentity.generated.swift` is generated from
`products/power/candidate.json`. It centralizes stack identity without copying
Program, Target, policy, or compatibility versions into handwritten Swift.

`Power2CandidateCatalog.generated.swift` is generated from the same candidate
hash chain plus its Program and model registry. It embeds only the exact
certification catalog and pinned workload/fixture bytes:

```bash
python3 scripts/generate_power2_app_catalog.py --check
```
