# Power 2 contribution intake

Each contributor pull request adds one or more UUID-named directories here.
Every directory contains exactly:

- `result.json` — the unmodified bytes exported by the Official App;
- `submission.json` — contributor identity, declarations, and the result
  digest.

Use `python3 scripts/power submit` to create a package. Do not hand-edit
`result.json`. Repository automation validates result-only pull requests
against the immutable Power pointer before they can be merged.
