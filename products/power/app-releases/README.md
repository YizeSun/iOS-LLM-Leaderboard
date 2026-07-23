# Power App releases

This directory owns immutable identities for distributed Power benchmark Apps.
It does not own Runner measurement behavior or Apple signing teams.

`candidate.json` is generated from the closed Power migration pointer. It
binds the future Official version/build, Bundle ID, complete App component
manifest SHA-256, embedded measurement-stack SHA-256, and the Runner
certificate it may support.

The candidate is not installable authority. A supported release record is
issued only after its Runner certificate is active, generic iOS builds pass,
and the exact Official physical-device rehearsal is reviewed. The Runner
certificate is active, the generic build gate passes, and the exact Official
build 2 end-to-end rehearsal is retained with a passing review. Immutable App
release issuance and public intake activation remain pending. Personal Team
IDs never enter this directory.

The exact Official candidate may measure during this closed rehearsal, but it
cannot submit, publish, or rank evidence while public intake is closed. Any
App, stack, or Runner digest change resets the affected generated verification
state and requires a new exact review.
