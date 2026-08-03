---
name: network-benchmarking
description: >-
  Rank a franchise owner's units against the whole network: sales per square
  foot, network performance percentile, sales per labor hour, and CSAT vs
  network average across Brand A and Brand B. Use when the owner asks "is this
  store top-quartile or bottom-quartile", "how do my units compare to the
  network", "which stores are least productive per square foot / per labor
  hour". Requires the unified semantic view to exist; honestly surfaces the
  ungrounded benchmark metrics (sq-ft, CSAT) as gaps with their required data,
  and applies the percentile-ranking pattern for grounded ones.
---

# Network benchmarking

Place each unit on a network percentile so the owner instantly knows if a store
is top- or bottom-quartile. This is inherently a network-wide comparison, so it
depends on the unified model.

## Hard prerequisite — STOP if not met

Benchmarking compares a unit against the **whole network across both brands**.
That requires:
1. The schema-remediation section of `scripts/setup.sql` has run (BRAND column
   + tables exist), and
2. The build-unified-semantic-view section has built the unified view.

If either is missing, STOP and route to `references/operational-runbook.md`.
A percentile over a single brand's stores is NOT a network percentile.

## Metrics this skill owns

| KPI | Formula | Status |
|-----|---------|--------|
| Network Performance Percentile Rank | `PERCENT_RANK() OVER (ORDER BY <metric>)` over unified network | GROUNDED once unified view exists |
| Sales per Labor Hour vs Network Avg | `net_sales / NULLIF(SUM(actual_hours),0)` vs network mean | PARTIAL (LABOR_WEEKLY drift) |
| Sales per Sq Ft vs Network Avg | `net_sales / store_square_feet` vs network mean | **GAP** (square footage missing) |
| CSAT vs Network Avg | avg CSAT vs network mean | **GAP** (no survey source) |

## Workflow (grounded metrics)

1. Confirm scope and that the unified view exists.
2. Rank with the percentile pattern (full form in `references/sql-patterns.md`):

   ```sql
   SELECT store_code, brand, net_sales,
          PERCENT_RANK() OVER (ORDER BY net_sales) AS network_pctile,
          NTILE(4)      OVER (ORDER BY net_sales) AS network_quartile
   FROM SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS
   WHERE month_start = DATE_TRUNC('month', CURRENT_DATE());
   ```

3. Report the owner's units WITH their network percentile and quartile, and name
   the network median for context. Segment or normalize by `BRAND` when
   comparing productivity, since ticket sizes differ (`domain-glossary`).

## Mandatory stopping points — ungrounded benchmarks

- **Sales per Sq Ft** — do not benchmark until `STORE_MASTER.SQUARE_FEET` is
  confirmed populated. Load contract: `references/missing-data-schemas.md`.
- **CSAT** — no survey source. Do not fabricate satisfaction scores. Elicit the
  survey feed.

For each, respond with the required source and the ingestion contract — never a
synthetic percentile.
