# Power product

Power measures one exact model artifact and runtime configuration on a
physical Apple device under a versioned Program and Target.

The first migration candidate contains:

- Product: `power`
- Program: `text-generation-performance@2.0.0-draft.2`
- Target: `apple-iphone-physical@1.0.0-draft.1`
- Model Catalog: four exact MLX artifacts selected only for new reruns

`candidate.json` pins a separate measurement-stack manifest. The future App
embeds that manifest digest, not the digest of a pointer that contains the App
itself.

The same pointer pins generated, closed Runner-certification and App-release
candidates. The Runner candidate binds every measurement-affecting Swift
component plus the canonical runtime identity. The App candidate binds the
complete App component manifest, exact stack, future Official bundle identity,
and the one Runner candidate it may support. Neither candidate is a
certificate or release.

The automated candidate suite and both generic iOS configurations pass for the
exact digests currently recorded in those files. The generator contains an
identity checkpoint, so any stack, Runner, or App digest change automatically
returns the affected automated state to `pending`. Physical-device smoke,
raw-result review, and end-to-end rehearsal remain pending.

The candidate is intentionally inactive. `current.json` must not be created
until the contract, runner certificate, physical-device reruns, trusted intake,
and contributor rehearsal all pass.

Power 1.1 files are not dependencies of this product tree.
