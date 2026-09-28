---
name: labor-optimization
description: >-
  Control the largest controllable cost: labor cost % of sales, sales per labor
  hour, overtime %, and employee turnover across Brand A and Brand B. Use when
  the owner asks "is my labor too high?", "which stores are overstaffed?",
  "how much overtime am I paying?". Checks LABOR_WEEKLY schema drift before
  running any metric and surfaces overtime/turnover gaps honestly.
---

# Labor optimization

Labor as a percent of sales per unit-week. Grounded on `LABOR_WEEKLY` and
`V_PRIME_COST_ANALYSIS`.

## Hard prerequisite — LABOR_WEEKLY schema drift

Pay columns (`regular_pay`, `overtime_pay`, `gross_pay`, `total_labor_cost`)
may be missing in a fresh environment. Confirm the schema-remediation section
of `scripts/setup.sql` has run before any labor metric. If absent, STOP →
`references/operational-runbook.md`.

## Metrics

| KPI | Status |
|-----|--------|
| Labor Cost % of Sales | PARTIAL (reconciled LABOR_WEEKLY required) |
| Sales per Labor Hour | PARTIAL |
| Overtime Hours % | **GAP** unless `overtime_hours` confirmed populated |
| Employee Turnover Rate | **GAP** — no separations feed |

## Workflow

```sql
SELECT l.store_code, l.week_start,
       ROUND(l.total_labor_cost / NULLIF(p.net_sales,0) * 100, 2) AS labor_cost_pct,
       ROUND(p.net_sales / NULLIF(l.total_actual_hours,0), 2)     AS sales_per_labor_hour
FROM SF_SOLUTIONS.OPS.V_LABOR_SUMMARY l
JOIN <weekly_net_sales_view> p ON l.store_id = p.store_id AND l.week_start = p.week_start;
```

High labor cost % + low sales-per-labor-hour = overstaffing for volume.
See prime-cost rollup in `references/sql-patterns.md`.

## Stopping points

- **Overtime %** — if `overtime_hours` not confirmed populated, treat as GAP.
- **Turnover** — GAP. No separations event in `LABOR_WEEKLY`. Load contract:
  `references/missing-data-schemas.md`.
