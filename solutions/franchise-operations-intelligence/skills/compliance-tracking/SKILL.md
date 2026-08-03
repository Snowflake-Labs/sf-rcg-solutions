---
name: compliance-tracking
description: >-
  Track brand-standards compliance for a franchise owner: brand audit score %,
  health/safety violations, corrective-action closure rate, and standards
  checklist compliance across Brand A and Brand B units. Use when the owner asks
  "are my stores passing brand audits", "which units have open violations", "are
  we closing corrective actions on time", "who's skipping the daily checklist".
  IMPORTANT: none of these KPIs have a grounded data source in the repo yet —
  this skill produces a load-readiness plan and ingestion contract, never a
  fabricated compliance score.
---

# Compliance tracking

Keep units on-standard for the franchisor. This is a compliance domain where
inventing a number is not just wrong — it is a franchisor-facing liability.
**Every KPI in this skill is currently ungrounded.**

## Grounding status — all GAP

| KPI | Required source | Status |
|-----|-----------------|--------|
| Brand Audit Score % | per-unit brand-audit feed (points earned ÷ possible) | **GAP** |
| Health/Safety Violations Count | inspection/violation events per unit-month | **GAP** |
| Corrective Action Closure Rate % | corrective-action open/close tracking with SLA | **GAP** |
| Standards Checklist Compliance % | daily standards-checklist completion per audit | **GAP** |

**Do not** substitute `FRANCHISEE_MASTER.BRAND_COMPLIANCE_SCORE` for Brand Audit
Score %. That field is at franchisee-organization grain, not per-unit
(`domain-glossary`: unit vs franchisee grain).

## Workflow — this is a load-readiness workflow, not an analysis one

1. **State the gap plainly.** When asked for any compliance KPI, respond:

   > "There is no audit/inspection/checklist data source in `SF_SOLUTIONS.OPS`
   > yet. I won't estimate a compliance score. Here's exactly what to ingest to
   > make this real."

2. **Hand the owner the ingestion contract** for the four required feeds — target
   schemas, grain, keys, and load pattern are specified in
   `references/missing-data-schemas.md`.

3. **Once loaded**, the metrics become straightforward counts/ratios per unit-
   month; a brand-audit-failure condition alert is pre-wired in the alerts
   section of `scripts/setup.sql` to fire when a unit's audit score breaches
   threshold.

## Mandatory stopping point

Refuse to produce any compliance figure until its source is loaded.
