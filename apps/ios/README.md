# Power 2 iOS App candidate

This directory now contains the clean Power 2 candidate App Shell. It has
separate Test and Results tabs, consumes the generated candidate identity, and
uses `PowerAppKit` for exact-byte result storage. It links the complete
candidate `PowerRunnerKit` implementation so generic iOS Release builds verify
the real dependency graph.

The project has three explicit build kinds:

- **Developer** — the normal Debug and Release configurations. It can inspect
  the App and local UI but cannot measure or submit ranking evidence.
- **Certification** — the maintainer-only physical-device smoke-test
  configuration. It can write candidate evidence but cannot submit or rank it.
- **Official** — the distribution configuration. It remains measurement- and
  submission-locked until an immutable App release, active runner certificate,
  active Power pointer, and open public intake are generated together.

The compiled kind and the `PowerBuildKind` value embedded in `Info.plist` must
agree. Overriding one build setting cannot turn a Developer build into an
Official build.

Apple signing is deliberately outside the pinned project. Copy the example
once and edit only the ignored local file:

```bash
cp apps/ios/Configuration/LocalSigning.example.xcconfig \
  apps/ios/Configuration/LocalSigning.xcconfig
```

Then replace `YOUR_TEAM_ID` in `LocalSigning.xcconfig`. Do not select a team in
the Xcode target editor because that writes a personal `DEVELOPMENT_TEAM` back
into the hashed project file. `Signing.xcconfig` is tracked and pinned;
`LocalSigning.xcconfig` is ignored and never enters an App, Runner, Program,
Target, or measurement identity.

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

`PowerOfficial` is a separately shared scheme and Bundle ID. Its presence does
not authorize a release: the generated release identity and repository intake
state remain authoritative. Community testers should eventually install the
maintainer-signed TestFlight/App Store build; source-built Apps remain
Developer builds even when signed by another Apple team.

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
