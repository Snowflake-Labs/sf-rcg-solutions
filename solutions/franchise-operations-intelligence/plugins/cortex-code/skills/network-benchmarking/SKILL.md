---
name: network-benchmarking
description: >-
  Rank a franchise owner's units against the whole network: network percentile,
  sales per sq ft, sales per labor hour, CSAT across Brand A and Brand B. Use
  when the owner asks "is this store top-quartile?", "how do my units compare
  to the network?". Requires the unified semantic view; surfaces ungrounded
  benchmarks (sq-ft, CSAT) as gaps rather than fabricating scores.
---

# Network benchmarking

Place each unit on a network percentile. Requires the unified semantic view
(`build-unified-semantic-view` section of `scripts/setup.sql` must have run).

## Hard prerequisite

A percentile over a single brand is NOT a network percentile. Both
`schema-remediation` and `build-unified-semantic-view` sections must have run.
If missing, STOP → `references/operational-runbook.md`.

## Metrics

| KPI | Status |
|-----|--------|
| Network Performance Percentile Rank | GROUNDED (unified view required) |
| Sales per Labor Hour vs Network | PARTIAL (LABOR_WEEKLY drift) |
| Sales per Sq Ft vs Network | **GAP** (square footage missing) |
| CSAT vs Network | **GAP** (no survey source) |

## Workflow (grounded)

```sql
SELECT store_code, brand, net_sales,
       PERCENT_RANK() OVER (ORDER BY net_sales) AS network_pctile,
       NTILE(4)       OVER (ORDER BY net_sales) AS network_quartile
FROM SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS
WHERE month_start = DATE_TRUNC('month', CURRENT_DATE());
```

Segment or normalize by `BRAND` — ticket sizes differ. See
`references/sql-patterns.md` for the full percentile pattern.

## Stopping points

- **Sales per Sq Ft** — do not benchmark until `STORE_MASTER.SQUARE_FEET` is
  populated. Load contract: `references/missing-data-schemas.md`.
- **CSAT** — no survey source. Do not fabricate. Elicit the survey feed.
