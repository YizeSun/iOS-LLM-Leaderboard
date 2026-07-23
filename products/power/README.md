# Power product

Power measures one exact model artifact and runtime configuration on a
physical Apple device under a versioned Program and Target.

The first migration candidate contains:

- Product: `power`
- Program: `text-generation-performance@2.0.0-draft.1`
- Target: `apple-iphone-physical@1.0.0-draft.1`
- Model Catalog: four exact MLX artifacts selected only for new reruns

`candidate.json` pins a separate measurement-stack manifest. The future App
embeds that manifest digest, not the digest of a pointer that contains the App
itself.

The candidate is intentionally inactive. `current.json` must not be created
until the contract, runner certificate, physical-device reruns, trusted intake,
and contributor rehearsal all pass.

Power 1.1 files are not dependencies of this product tree.
