# Power 1.0 Evidence Reviews — Adopted RC.1 Contract

This directory stores accepted, immutable evidence-transition records using
`suite-b-power-review-1.0.0-rc.1`.

Review filenames must equal `<reviewID>.json`. Review records bind a Draft
manifest and result by SHA-256. They never modify the source package or frozen
Power 1.0 release. The retained RC1 review schema cannot itself publish or rank
evidence; a separate publication decision is required.

Validate the complete transition history with:

```bash
python3 scripts/validate_suite_b_power_reviews.py \
  --submissions submissions/suite-b/power-1.0.0-rc.1/draft \
  --reviews submissions/suite-b/power-1.0.0-rc.1/reviews
```
