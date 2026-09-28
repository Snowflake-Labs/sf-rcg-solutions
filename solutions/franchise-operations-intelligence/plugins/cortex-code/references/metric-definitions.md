# Metric Definitions — Canonical Catalog (25 KPIs)

## COGS% resolution of record

Three variants existed across brand app-stacks. **Canonical:**

```
COGS % = SUM(TOTAL_FOOD_COST) / NULLIF(SUM(TOTAL_AMOUNT), 0) * 100  -- COGS ÷ NET sales
```

Variant dividing by `SUBTOTAL` (gross sales) is legacy brand-local — migrate it.
`DT_STORE_MONTH_KPIS.cogs_pct` and `FRANCHISE_OPS_UNIFIED.cogs_pct` both implement
the canonical form.

## Full catalog

### Job 1 — Unit performance
| # | KPI | Formula | Status |
|---|-----|---------|--------|
| 1 | Net Sales | `SUM(TOTAL_AMOUNT)` | GROUNDED |
| 2 | Gross Margin % | `SUM(GROSS_PROFIT)/NULLIF(SUM(SUBTOTAL),0)*100` | GROUNDED |
| 3 | Transaction Count | `COUNT(TRANSACTION_ID)` | GROUNDED |
| 4 | Same-Store Sales Growth | `(NS_curr-NS_prior)/NULLIF(NS_prior,0)*100`, comp units | PARTIAL |
| 5 | EBITDA / Store Profit | store-level P&L rollup | GAP |

### Job 2 — Benchmarking
| # | KPI | Status |
|---|-----|--------|
| 6 | Sales per Sq Ft vs Network | GAP (square footage) |
| 7 | Network Percentile Rank | GROUNDED (unified view required) |
| 8 | Sales per Labor Hour vs Network | PARTIAL |
| 9 | CSAT vs Network | GAP |

### Job 3 — Labor
| # | KPI | Status |
|---|-----|--------|
| 10 | Labor Cost % of Sales | PARTIAL |
| 11 | Sales per Labor Hour | PARTIAL |
| 12 | Overtime Hours % | GAP unless confirmed |
| 13 | Employee Turnover Rate | GAP |

### Job 4 — COGS & waste
| # | KPI | Status |
|---|-----|--------|
| 14 | COGS % of Sales | GROUNDED (canonical: COGS ÷ net sales) |
| 15 | Inventory Variance % | GROUNDED |
| 16 | Waste % of Purchases | GAP |
| 17 | Shrinkage $ Loss | GAP |

### Jobs 5–6 — Compliance & Expansion (all GAP)

All 8 KPIs across compliance and expansion are ungrounded. Load contracts in
`missing-data-schemas.md`.

## Rule

Never emit a value for a GAP metric. Return the load contract.
