# Metric Definitions — Canonical Catalog (all 25 KPIs)

Component: `cmp-metric-definitions-ref` (solution_design). The authoritative
formula contract. `skills/kpi-definitions` is the interactive front door; this
file is the durable catalog. Where a metric is ungrounded, the load contract is
in `missing-data-schemas.md`.

## The COGS% conflict — resolution of record

Three variants existed across brand app-stacks:

- **A.** `TOTAL_FOOD_COST / TOTAL_AMOUNT` (COGS ÷ net sales)
- **B.** an alternate per-transaction derived `cogs_pct`
- **C.** `food_cost_pct = TOTAL_FOOD_COST / SUBTOTAL` (COGS ÷ gross sales)

**Ratified canonical definition:**

```
COGS % of Sales = SUM(TOTAL_FOOD_COST) / NULLIF(SUM(TOTAL_AMOUNT), 0) * 100
```

i.e. **COGS ÷ NET sales**. Variant C (`÷ SUBTOTAL`) is legacy brand-local and
must be migrated. `DT_STORE_MONTH_KPIS.cogs_pct` and the unified view's
`cogs_pct` both implement the canonical form.

## Full catalog

### Job 1 — Unit performance
| # | KPI | Formula | Grain | Status |
|---|-----|---------|-------|--------|
| 1 | Net Sales | `SUM(TOTAL_AMOUNT)` | store-day/month | GROUNDED |
| 2 | Gross Margin % | `SUM(GROSS_PROFIT)/NULLIF(SUM(SUBTOTAL),0)*100` | store-month | GROUNDED |
| 3 | Transaction Count | `COUNT(TRANSACTION_ID)` | store-day | GROUNDED |
| 4 | Same-Store Sales Growth | `(NS_curr-NS_prior_yr)/NULLIF(NS_prior_yr,0)*100`, comp units only | store-month | PARTIAL |
| 5 | EBITDA / Store Profit | store P&L rollup | store-month | GAP |

### Job 2 — Benchmarking
| # | KPI | Formula | Status |
|---|-----|---------|--------|
| 6 | Sales per Sq Ft vs Network Avg | `net_sales / square_feet` vs network mean | GAP (square footage) |
| 7 | Network Percentile Rank | `PERCENT_RANK() OVER (ORDER BY metric)` | GROUNDED once unified view built |
| 8 | Sales per Labor Hour vs Network Avg | `net_sales/NULLIF(SUM(actual_hours),0)` vs mean | PARTIAL |
| 9 | CSAT vs Network Avg | avg CSAT vs mean | GAP |

### Job 3 — Labor
| # | KPI | Formula | Status |
|---|-----|---------|--------|
| 10 | Labor Cost % of Sales | `SUM(total_labor_cost)/NULLIF(net_sales,0)*100` | PARTIAL |
| 11 | Sales per Labor Hour | `net_sales/NULLIF(SUM(actual_hours),0)` | PARTIAL |
| 12 | Overtime Hours % | `SUM(overtime_hours)/NULLIF(SUM(actual_hours),0)*100` | GAP unless confirmed |
| 13 | Employee Turnover Rate | `separations/avg_headcount` | GAP |

### Job 4 — COGS & waste
| # | KPI | Formula | Status |
|---|-----|---------|--------|
| 14 | COGS % of Sales | `SUM(TOTAL_FOOD_COST)/NULLIF(SUM(TOTAL_AMOUNT),0)*100` | GROUNDED (canonical) |
| 15 | Inventory Variance % | `FOOD_COST_WEEKLY.variance_pct` | GROUNDED |
| 16 | Waste % of Purchases | `waste_cost/NULLIF(purchases,0)*100` | GAP |
| 17 | Shrinkage $ Loss | `theoretical_usage - actual_usage` (loss) | GAP |

### Job 5 — Compliance (all GAP)
| # | KPI | Formula | Status |
|---|-----|---------|--------|
| 18 | Brand Audit Score % | `points_earned/NULLIF(points_possible,0)*100` | GAP |
| 19 | Health/Safety Violations Count | `SUM(violations_count)` | GAP |
| 20 | Corrective Action Closure Rate % | `closed/NULLIF(opened,0)*100` | GAP |
| 21 | Standards Checklist Compliance % | `items_done/NULLIF(items_total,0)*100` | GAP |

### Job 6 — Expansion (all GAP)
| # | KPI | Formula | Status |
|---|-----|---------|--------|
| 22 | Unit-Level ROI % | `annual_unit_profit/total_invested_capital*100` | GAP |
| 23 | Payback Period | `total_investment/annual_unit_cash_flow` | GAP |
| 24 | Projected Sales (Trade Area) | regression on comparable units | GAP |
| 25 | Cash-on-Cash Return % | `annual_pretax_cash_flow/equity_invested*100` | GAP |

## Prime cost (supporting)

`prime_cost_pct = (food_cost + labor_cost) / NULLIF(gross_sales,0) * 100`

Prime cost combines KPIs 10 and 14 and is the owner's core controllable view;
the rollup pattern is in `sql-patterns.md`.

## Rule

Never emit a value for a GAP metric. Emit its load contract instead
(`missing-data-schemas.md`). This is the operational_excellence + ai_data_governance
posture of the solution.
