# Unified Semantic View — Design Reference

Companion to the `build-unified-semantic-view` section of `scripts/setup.sql`.
Documents the entity/dimension/metric mapping for
`SF_SOLUTIONS.OPS.FRANCHISE_OPS_UNIFIED`.

## Why one view

Three disconnected brand app-stacks, no shared model. The unified view is the
single governed model for Cortex Analyst and `franchise-analyst`, with a `BRAND`
dimension so Brand A and Brand B are always separable.

## Entities

| Logical table | Base table | Key |
|---|---|---|
| `stores` | `STORE_MASTER` | `STORE_ID` |
| `txns` | `POS_TRANSACTIONS` | `TRANSACTION_ID` |
| `franchisees` | `FRANCHISEE_MASTER` | `FRANCHISEE_ID` |

Relationship: `txns.STORE_ID → stores.STORE_ID`.

## Metrics (grounded only)

| Metric | Expression |
|---|---|
| net_sales | `SUM(TOTAL_AMOUNT)` — canonical top line |
| gross_sales | `SUM(SUBTOTAL)` — pre-tax; NOT the COGS% denominator |
| gross_profit | `SUM(GROSS_PROFIT)` |
| transaction_count | `COUNT(TRANSACTION_ID)` |
| total_cogs | `SUM(TOTAL_FOOD_COST)` |
| gross_margin_pct | `SUM(GROSS_PROFIT)/NULLIF(SUM(SUBTOTAL),0)*100` |
| cogs_pct | `SUM(TOTAL_FOOD_COST)/NULLIF(SUM(TOTAL_AMOUNT),0)*100` — **canonical** |
| avg_ticket | `AVG(TOTAL_AMOUNT)` |

**Intentionally excluded** (ungrounded): sales/sqft, CSAT, labor, overtime,
turnover, waste, shrinkage, all compliance, all expansion KPIs.

## Verified queries

```sql
SELECT * FROM SEMANTIC_VIEW(SF_SOLUTIONS.OPS.FRANCHISE_OPS_UNIFIED
  DIMENSIONS stores.brand METRICS txns.net_sales, txns.cogs_pct);

SELECT * FROM SEMANTIC_VIEW(SF_SOLUTIONS.OPS.FRANCHISE_OPS_UNIFIED
  DIMENSIONS stores.store_code, stores.brand METRICS txns.net_sales)
ORDER BY net_sales DESC LIMIT 20;
```

Row-access and masking policies from `references/governance-and-access.md` apply
automatically — the agent only sees rows the caller's role is entitled to.
