---
name: kpi-definitions
description: >-
  Canonical, single-source-of-truth definitions for every franchise operations
  KPI (Brand A, Brand B, 25 total). Use when someone asks "how do we define net
  sales / COGS% / labor cost% / same-store sales / unit ROI", when two reports
  disagree, or when you need the exact formula and grounding status before
  writing SQL. Flags the 14 ungrounded KPIs so you never fabricate a number.
---

# Franchise KPI Definitions — the metric contract

Metric authority for `SF_SOLUTIONS.OPS`. Every number must trace to exactly one
definition. Never emit a plausible-looking value for a GAP metric.

## Grounding legend

- **GROUNDED** — source exists in `SF_SOLUTIONS.OPS` today.
- **PARTIAL** — base measure exists; full metric needs schema fix or logic.
- **GAP** — no source; must be ingested before use.

## Job 1 — Unit performance

| KPI | Formula | Status |
|-----|---------|--------|
| Net Sales | `SUM(TOTAL_AMOUNT)` | GROUNDED |
| Gross Margin % | `SUM(GROSS_PROFIT)/NULLIF(SUM(SUBTOTAL),0)*100` | GROUNDED |
| Transaction Count | `COUNT(TRANSACTION_ID)` | GROUNDED |
| Same-Store Sales Growth | `(NS_curr-NS_prior)/NULLIF(NS_prior,0)*100`, comp units only | PARTIAL |
| EBITDA / Store Profit | store-level P&L rollup | **GAP** |

## Job 2 — Network benchmarking

| KPI | Formula | Status |
|-----|---------|--------|
| Network Percentile Rank | `PERCENT_RANK() OVER (ORDER BY metric)` | GROUNDED (unified view required) |
| Sales per Sq Ft | `net_sales / square_feet` | **GAP** (square footage missing) |
| Sales per Labor Hour | `net_sales / SUM(actual_hours)` | PARTIAL (LABOR_WEEKLY drift) |
| CSAT vs Network | avg CSAT vs mean | **GAP** (no survey source) |

## Job 3 — Labor

| KPI | Formula | Status |
|-----|---------|--------|
| Labor Cost % of Sales | `SUM(total_labor_cost)/NULLIF(net_sales,0)*100` | PARTIAL |
| Sales per Labor Hour | `net_sales/NULLIF(SUM(actual_hours),0)` | PARTIAL |
| Overtime Hours % | `SUM(overtime_hours)/NULLIF(SUM(actual_hours),0)*100` | **GAP** unless confirmed |
| Employee Turnover Rate | `separations/avg_headcount` | **GAP** |

## Job 4 — COGS & waste

| KPI | Formula | Status |
|-----|---------|--------|
| **COGS % of Sales (canonical)** | `SUM(TOTAL_FOOD_COST)/NULLIF(SUM(TOTAL_AMOUNT),0)*100` | GROUNDED |
| Inventory Variance % | `FOOD_COST_WEEKLY.variance_pct` | GROUNDED |
| Waste % of Purchases | `waste_cost/NULLIF(purchases,0)*100` | **GAP** |
| Shrinkage $ Loss | theoretical − actual usage | **GAP** |

### COGS % resolution

Canonical = **COGS ÷ net sales** (`TOTAL_AMOUNT`). Any legacy report using
`÷ SUBTOTAL` is wrong. Full write-up: `references/metric-definitions.md`.

## Jobs 5–6 — Compliance & Expansion (all GAP)

All 4 compliance KPIs and all 4 expansion KPIs are ungrounded. Never invent
values. Return the load contract from `references/missing-data-schemas.md`.

## Stopping rule

> "That KPI has no grounded source in `SF_SOLUTIONS.OPS` yet. Required load
> contract: see `references/missing-data-schemas.md`."
