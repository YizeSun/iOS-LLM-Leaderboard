# Product contracts

This directory is the normative home for the clean-break product
architecture.

- `power/` owns Power Programs, Targets, policies, runner certificates, and
  release pointers.
- `ship/` will own separate Ship Programs and policies when its migration is
  approved.

Released contracts and manifests are CC BY 4.0. Executable App and tool code
remains MIT-licensed in `apps/` and `scripts/`.

Power 2.0 is being built as a new major contract. Nothing in this directory may
import, translate, validate, rank, or promote Power 1.0 or 1.1 evidence. Those
releases remain a read-only historical evidence plane at their retained paths.

Until `products/power/current.json` is published during the atomic cutover,
all Power 2.0 files are migration candidates and do not open public intake.
