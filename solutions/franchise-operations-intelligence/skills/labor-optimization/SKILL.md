---
name: labor-optimization
description: >-
  Control the largest controllable cost line for a franchise owner: labor cost %
  of sales, sales per labor hour, overtime %, and employee turnover across Brand A
  and Brand B units. Use when the owner asks "is my labor too high", "which
  stores are overstaffed for their volume", "how much overtime am I paying",
  "are schedules matched to demand". Grounded on LABOR_WEEKLY / V_PRIME_COST_
  ANALYSIS in SF_SOLUTIONS.OPS but depends on the reconciled LABOR_WEEKLY schema —
  it checks for schema drift first and surfaces overtime/turnover gaps honestly.
---

# Labor optimization

Show labor as a percent of sales per unit-week so the owner keeps staffing in
line with volume — labor is the largest controllable cost. Grounded on
`LABOR_WEEKLY` and `V_PRIME_COST_ANALYSIS`.

## Hard prerequisite — LABOR_WEEKLY schema drift

`LABOR_WEEKLY` has known schema drift. Pay columns (`regular_pay`, `overtime_pay`,
`gross_pay`, `total_labor_cost`) may be missing in a fresh environment.
**Before running any labor metric, confirm the reconciled schema** via the
schema-remediation section of `scripts/setup.sql`. If columns are absent, STOP
and route to `references/operational-runbook.md`.

## Metrics this skill owns

| KPI | Formula | Status |
|-----|---------|--------|
| Labor Cost % of Sales | `SUM(total_labor_cost)/NULLIF(net_sales,0)*100` | PARTIAL (needs reconciled LABOR_WEEKLY) |
| Sales per Labor Hour | `net_sales/NULLIF(SUM(actual_hours),0)` | PARTIAL |
| Overtime Hours % | `SUM(overtime_hours)/NULLIF(SUM(actual_hours),0)*100` | GAP unless overtime_hours confirmed populated |
| Employee Turnover Rate | `separations/avg_headcount` | **GAP — no separations feed** |

## Workflow

1. **Verify schema** (above). 2. **Confirm scope** — brand/unit/week, owner→unit
   row scoping. 3. Roll up weekly from `V_LABOR_SUMMARY` / `LABOR_WEEKLY`:

   ```sql
   SELECT l.store_code, l.week_start,
          l.total_labor_cost,
          l.total_actual_hours,
          l.total_overtime_hours,
          ROUND(l.total_labor_cost / NULLIF(p.net_sales,0) * 100, 2) AS labor_cost_pct,
          ROUND(p.net_sales / NULLIF(l.total_actual_hours,0), 2)     AS sales_per_labor_hour
   FROM SF_SOLUTIONS.OPS.V_LABOR_SUMMARY l
   JOIN <weekly_net_sales_view> p
     ON l.store_id = p.store_id AND l.week_start = p.week_start;
   ```

4. **Interpret** — a high labor cost % with low sales-per-labor-hour signals
   overstaffing for volume; recommend schedule tuning to demand (`DAYPART` mix in
   `POS_TRANSACTIONS`). Present prime cost (labor + COGS) via
   `V_PRIME_COST_ANALYSIS.prime_cost_pct` for the full controllable picture; see
   the prime-cost rollup pattern in `references/sql-patterns.md`.

## Mandatory stopping points

- **Overtime Hours %** — may be unreliable. If, post-remediation, `overtime_hours`
  is confirmed populated, compute it and label PARTIAL; otherwise treat as GAP
  and elicit the source. Do not report a fabricated OT %.
- **Employee Turnover Rate** — GAP. `LABOR_WEEKLY` has `hire_date`/`tenure_days`
  but no separations event. Do not infer turnover. Load contract:
  `references/missing-data-schemas.md`.
