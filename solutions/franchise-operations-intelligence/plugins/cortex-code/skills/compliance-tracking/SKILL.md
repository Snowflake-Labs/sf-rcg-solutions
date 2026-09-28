---
name: compliance-tracking
description: >-
  Track brand-standards compliance: brand audit score %, health/safety
  violations, corrective-action closure rate, and standards checklist compliance
  across Brand A and Brand B. IMPORTANT: none of these KPIs have a grounded
  data source yet — this skill produces a load-readiness plan and ingestion
  contract, never a fabricated score.
---

# Compliance tracking

All 4 compliance KPIs are currently ungrounded. Inventing a number is a
franchisor-facing liability. This skill is a **load-readiness workflow**.

## Status — all GAP

| KPI | Required source | Status |
|-----|-----------------|--------|
| Brand Audit Score % | per-unit brand-audit feed | **GAP** |
| Health/Safety Violations Count | inspection events per unit-month | **GAP** |
| Corrective Action Closure Rate % | open/close tracking with SLA | **GAP** |
| Standards Checklist Compliance % | daily checklist completion | **GAP** |

`FRANCHISEE_MASTER.BRAND_COMPLIANCE_SCORE` is org-grain — do NOT substitute for
per-unit audit score.

## Workflow

1. State the gap:
   > "No audit/inspection/checklist data in `SF_SOLUTIONS.OPS` yet. Here's
   > exactly what to ingest."
2. Hand the owner the ingestion contract from `references/missing-data-schemas.md`.
3. Once loaded: the `ALERT_COMPLIANCE_FAILURE` in `scripts/setup.sql` fires when
   audit score breaches threshold.

Refuse any compliance figure until its source is loaded.
