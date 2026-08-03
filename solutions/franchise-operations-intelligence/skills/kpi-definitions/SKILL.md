---
name: kpi-definitions
description: >-
  Canonical, single-source-of-truth definitions for every franchise operations
  KPI across the QSR network (Brand A, Brand B). Use this when someone asks "how
  do we define net sales / gross margin / COGS % / prime cost / labor cost % /
  same-store sales / unit ROI", when two reports disagree on a number, when you
  need the exact formula, grain, and source table before writing SQL, or when a
  metric might not have grounded data yet. Covers all 25 KPIs and flags the ones
  that are NOT yet backed by data so you never fabricate a number. Not for
  building dashboards or running the query itself — this is the definition layer
  the other skills and the agent depend on.
---

# Franchise KPI Definitions — the metric contract

You are the metric authority for a multi-unit franchise owner operating both
Brand A and Brand B units on `SF_SOLUTIONS.OPS`. Every number that reaches this
owner must trace to exactly one definition. When there is ambiguity, you resolve
it here — you do not let two skills compute "COGS %" two different ways.

## How to use this skill

1. Identify the KPI the user named (or the closest canonical KPI below).
2. Return its **formula, grain, source, and grounding status** verbatim.
3. If the KPI is marked **GAP (ungrounded)**, do NOT invent a formula or a
   value. State plainly that the data source does not exist yet and point to
   `references/missing-data-schemas.md` for the required ingestion contract.
4. If asked to compute it, hand off to the matching job skill
   (`unit-performance-monitoring`, `network-benchmarking`, `labor-optimization`,
   `cogs-waste-control`, `compliance-tracking`, `expansion-evaluation`) and pass
   along the exact formula from here.

## Grounding legend

- **GROUNDED** — backed by an object that exists in `SF_SOLUTIONS.OPS` today.
- **PARTIAL** — base measure exists but the full metric needs additional logic
  or a schema fix (see the schema-remediation section of `scripts/setup.sql`).
- **GAP (ungrounded)** — no source in the repo; must be ingested before use.
  Elicit the source; do not invent.

## Job 1 — Unit performance (P&L monitoring)

| KPI | Formula | Grain | Source | Status |
|-----|---------|-------|--------|--------|
| Net Sales | `SUM(POS_TRANSACTIONS.TOTAL_AMOUNT)` | store-day → store-month | `V_STORE_PERFORMANCE_SUMMARY.net_sales` | GROUNDED |
| Gross Margin % | `SUM(GROSS_PROFIT) / NULLIF(SUM(SUBTOTAL),0) * 100` | store-month | `V_STORE_PERFORMANCE_SUMMARY.gross_margin_pct` | GROUNDED |
| Transaction Count | `COUNT(TRANSACTION_ID)` | store-day | `V_STORE_PERFORMANCE_SUMMARY.total_transactions` | GROUNDED |
| Same-Store Sales Growth | `(NET_SALES_curr - NET_SALES_prioryear) / NULLIF(NET_SALES_prioryear,0) * 100`, comp units only | store-month | base `net_sales` GROUNDED; prior-year logic PARTIAL | Use pattern in `references/sql-patterns.md`. |
| EBITDA / Store Profit | store-level P&L rollup | store-month | none | **GAP (ungrounded)** — requires store-level P&L. Do not invent. |

## Job 2 — Network benchmarking

| KPI | Formula | Grain | Source | Status |
|-----|---------|-------|--------|--------|
| Sales per Sq Ft vs Network Avg | `net_sales / store_square_feet`, ranked vs network mean | store | `net_sales` GROUNDED; square footage missing | **GAP** — confirm `STORE_MASTER.SQUARE_FEET` is populated before use. |
| Network Performance Percentile Rank | `PERCENT_RANK() OVER (ORDER BY <metric>)` across the unified network | store | unified network dataset | GROUNDED once unified view built. |
| Sales per Labor Hour vs Network Avg | `net_sales / SUM(LABOR_WEEKLY.actual_hours)` | store-week | `net_sales` GROUNDED; `LABOR_WEEKLY` PARTIAL (schema drift) | PARTIAL — depends on reconciled `LABOR_WEEKLY`. |
| Customer Satisfaction Score vs Network Avg | avg CSAT vs network mean | store | none | **GAP (ungrounded)** — no survey source. Do not invent. |

## Job 3 — Labor optimization

| KPI | Formula | Grain | Source | Status |
|-----|---------|-------|--------|--------|
| Labor Cost % of Sales | `SUM(LABOR_WEEKLY.total_labor_cost) / NULLIF(net_sales,0) * 100` | store-week | `V_PRIME_COST_ANALYSIS` (labor component), `LABOR_WEEKLY` | PARTIAL — depends on reconciled `LABOR_WEEKLY`. |
| Sales per Labor Hour | `net_sales / NULLIF(SUM(LABOR_WEEKLY.actual_hours),0)` | store-week | `LABOR_WEEKLY.actual_hours` | PARTIAL (schema drift). |
| Overtime Hours % | `SUM(overtime_hours) / NULLIF(SUM(actual_hours),0) * 100` | store-week | `LABOR_WEEKLY.overtime_hours` | **GAP** — confirm field is populated post-remediation before use. |
| Employee Turnover Rate | `separations / avg_headcount` | store-period | none | **GAP (ungrounded)** — no headcount/separations source. Do not invent. |

## Job 4 — COGS & waste control

| KPI | Formula | Grain | Source | Status |
|-----|---------|-------|--------|--------|
| COGS % of Sales | **CANONICAL: `SUM(TOTAL_FOOD_COST) / NULLIF(SUM(TOTAL_AMOUNT),0) * 100`** (COGS ÷ net sales) | store-week | `POS_TRANSACTIONS` | GROUNDED — see conflict resolution below. |
| Inventory Variance % | `FOOD_COST_WEEKLY.variance_pct` = `(actual_cost - theoretical_cost) / NULLIF(theoretical_cost,0) * 100` | store-week | `FOOD_COST_WEEKLY.variance_pct` | GROUNDED. |
| Waste % of Purchases | `waste_cost / NULLIF(purchases,0) * 100` | store-week | none | **GAP (ungrounded)** — no waste/purchases feed. Do not invent. |
| Shrinkage $ Loss | `theoretical_usage_cost - actual_usage_cost` attributable to loss | store-month | none | **GAP (ungrounded)** — no shrinkage source. Do not invent. |

### COGS % conflict resolution (ratified)

Multiple COGS% definitions existed, including one dividing by `SUBTOTAL` (gross
sales). The **canonical COGS % is `TOTAL_FOOD_COST ÷ TOTAL_AMOUNT` (COGS over
net sales)**. Full write-up in `references/metric-definitions.md`.

## Job 5 — Compliance tracking (all GAP)

| KPI | Formula | Source | Status |
|-----|---------|--------|--------|
| Brand Audit Score % | audit points earned ÷ possible | none | **GAP (ungrounded)** — `FRANCHISEE_MASTER.BRAND_COMPLIANCE_SCORE` is org-level, not per-unit. |
| Health/Safety Violations Count | count per unit-month | none | **GAP** — no inspection source. Do not invent. |
| Corrective Action Closure Rate % | closed ÷ opened within SLA | none | **GAP** — no corrective-action tracking. Do not invent. |
| Standards Checklist Compliance % | items complete ÷ items required | none | **GAP** — no checklist source. Do not invent. |

## Job 6 — Expansion evaluation (all GAP)

| KPI | Formula | Source | Status |
|-----|---------|--------|--------|
| Unit-Level ROI % | `annual_unit_profit / total_invested_capital * 100` | none | **GAP (ungrounded)** — needs unit P&L + investment basis. |
| Payback Period | `total_investment / annual_unit_cash_flow` | none | **GAP** — needs unit cash flow + capex. |
| Projected Sales for New Site | trade-area regression on comparable units | none | **GAP** — needs trade-area demographics. Escalated as Marketplace build/buy. |
| Cash-on-Cash Return % | `annual_pretax_cash_flow / equity_invested * 100` | none | **GAP** — needs unit cash flow + equity invested. |

## Stopping rule

If a requested KPI is **GAP (ungrounded)**, stop and return:
> "That KPI has no grounded data source in `SF_SOLUTIONS.OPS` yet. I won't
> estimate it. Required source and load contract: see
> `references/missing-data-schemas.md`."

Never emit a plausible-looking number for an ungrounded metric.
