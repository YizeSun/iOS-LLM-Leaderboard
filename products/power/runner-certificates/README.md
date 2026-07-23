# Power runner certificates

The first active Power 2.0 Runner certificate is
`power2-runner-87f62feecc2b.json`. It binds the exact Runner components,
runtime identity, text Program, physical-iPhone Target, release-candidate
measurement stack, and runner-certification policy.

The certificate was issued from the retained closed Certification evidence in
`evidence/b5d3c2cf-b2b8-4060-b00d-048102e6cfb9/`. That directory preserves the
raw physical-iPhone result byte-for-byte, its review report, and the exact App
component-manifest snapshot that produced it. The evidence and certificate
remain non-publishable and non-ranking; they establish measurement trust only.

`candidate.json` remains the generated certification audit surface. It records
the current Runner component identity, automated checks, the retained physical
review, and the active certificate reference. All checks pass only for the
exact digests recorded by the generator checkpoint. Changing the stack or
Runner identity creates a new candidate and requires new certification rather
than mutating this certificate.

An active Runner certificate does not release the App or open public intake.
The next closed gate is an end-to-end physical rehearsal of the exact Official
App release candidate.

Power 1.1 compatible-runner records are not imported.
