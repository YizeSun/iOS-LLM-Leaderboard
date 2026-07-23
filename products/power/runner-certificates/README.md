# Power runner certificates

No active Power 2.0 runner certificate has been issued.

`candidate.json` is the generated, closed certification identity. It binds the
new Runner Core, text Program Module, iPhone Target Adapter, Runtime Adapter,
evidence encoder, canonical runtime identity, Program, Target, measurement
stack, and certification policy. Its automated and physical verification
states remain explicit.

All automated fields currently pass only for the exact stack and Runner
component digests recorded by the release-candidate generator checkpoint.
Changing either digest resets those fields to `pending`. Physical-device smoke
and raw-result review remain pending.

An immutable active certificate is issued only after the generated candidate,
Release build, physical-device smoke run, and exact raw-result review satisfy
the runner-certification policy. Candidate review may never authorize public
intake, submission, ranking, or publication.

Power 1.1 compatible-runner records are not imported.
