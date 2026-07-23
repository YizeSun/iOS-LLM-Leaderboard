# Power App releases

This directory owns immutable identities for distributed Power benchmark Apps.
It does not own Runner measurement behavior or Apple signing teams.

`candidate.json` is generated from the closed Power migration pointer. It
binds the future Official version/build, Bundle ID, complete App component
manifest SHA-256, embedded measurement-stack SHA-256, and the Runner
certification candidate it may support.

The candidate is not installable authority. A supported release record is
issued only after its Runner certificate is active, both generic iOS builds
pass, and the physical-device rehearsal is reviewed. Personal Team IDs never
enter this directory.

Both generic iOS configurations currently pass for the exact App component
manifest recorded by the release-candidate generator checkpoint. Any App,
stack, or Runner digest change resets the generated build-verification state to
`pending`.
