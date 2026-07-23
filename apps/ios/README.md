# Power 2 iOS App candidate

This directory now contains the clean Power 2 candidate App Shell. It has
separate Test and Results tabs, consumes the generated candidate identity, and
uses `PowerAppKit` for exact-byte result storage. It links the complete
candidate `PowerRunnerKit` implementation so generic iOS Release builds verify
the real dependency graph.

The candidate deliberately disables measurement and GitHub submission because
there is no released App identity, runner certificate, active Power pointer,
or open public intake. This fail-closed state prevents a migration build from
producing evidence that looks official.

The current `ios-app/` remains the Power 1.1 public App until the atomic
clean-break cutover. No Power 1.1 result is imported, converted, displayed, or
submitted by this candidate.

`Power2CandidateIdentity.generated.swift` is generated from
`products/power/candidate.json`. It centralizes stack identity without copying
Program, Target, policy, or compatibility versions into handwritten Swift.
