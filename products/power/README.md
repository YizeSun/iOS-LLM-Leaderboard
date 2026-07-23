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

The same pointer pins the active Runner certificate and the closed App-release
candidate. The Runner certificate binds every measurement-affecting Swift
component plus the canonical runtime identity and retained physical
Certification evidence. The App candidate binds the complete App component
manifest, exact release-candidate stack, future Official bundle identity, and
the active Runner certificate it may support. No App release has been issued.

The automated candidate suite, both generic iOS configurations, Runner
physical-device smoke, and raw-result review pass for the exact recorded
digests. The generator contains an identity checkpoint, so any stack, Runner,
or App digest change automatically returns the affected state to `pending`.
The exact Official App end-to-end physical rehearsal remains pending.

The candidate is intentionally inactive. `current.json` must not be created
until the contract, runner certificate, physical-device reruns, trusted intake,
and contributor rehearsal all pass.

Power 1.1 files are not dependencies of this product tree.
