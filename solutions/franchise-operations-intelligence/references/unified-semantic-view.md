# Unified Semantic View — Design Reference

Component: `cmp-semantic-view-reference` (solution_design). Companion to
the `build-unified-semantic-view` section of `scripts/setup.sql`. Documents
the entity/dimension/metric mapping, synonyms, and verified queries for
`SF_SOLUTIONS.OPS.FRANCHISE_OPS_UNIFIED`.

## Why one view

Three disconnected brand app-stacks existed with no shared model. The unified
view is the single governed model Cortex Analyst and the `franchise-analyst`
agent query, with a `BRAND` dimension so Brand A and Brand B are always separable.

## Entities

| Logical table | Base table | Grain | Key |
|---|---|---|---|
| `stores` | `STORE_MASTER` | one row per unit | `STORE_ID` |
| `txns` | `POS_TRANSACTIONS` | one row per transaction | `TRANSACTION_ID` |
| `franchisees` | `FRANCHISEE_MASTER` | one row per operator org | `FRANCHISEE_ID` |

Relationship: `txns.STORE_ID → stores.STORE_ID`.

## Dimensions & synonyms

| Dimension | Column | Synonyms |
|---|---|---|
| brand | `stores.BRAND` | chain, banner |
| store_code | `stores.STORE_CODE` | store number, unit code |
| region | `stores.REGION` | territory, area |
| store_format | `stores.STORE_FORMAT` | — |
| daypart | `txns.DAYPART` | — |
| order_channel | `txns.ORDER_CHANNEL` | channel, order type |
| transaction_date | `txns.TRANSACTION_DATE` | — |
| franchisee_tier | `franchisees.FRANCHISEE_TIER` | tier |

## Metrics (grounded only)

| Metric | Expression | Notes |
|---|---|---|
| net_sales | `SUM(TOTAL_AMOUNT)` | canonical top line |
| gross_sales | `SUM(SUBTOTAL)` | pre-tax; NOT the COGS% denominator |
| gross_profit | `SUM(GROSS_PROFIT)` | |
| transaction_count | `COUNT(TRANSACTION_ID)` | traffic |
| total_cogs | `SUM(TOTAL_FOOD_COST)` | |
| gross_margin_pct | `SUM(GROSS_PROFIT)/NULLIF(SUM(SUBTOTAL),0)*100` | |
| cogs_pct | `SUM(TOTAL_FOOD_COST)/NULLIF(SUM(TOTAL_AMOUNT),0)*100` | **canonical: COGS ÷ net sales** |
| avg_ticket | `AVG(TOTAL_AMOUNT)` | |

**Intentionally excluded** (ungrounded — see `missing-data-schemas.md`): sales
per sq ft, CSAT, labor cost %, overtime, turnover, waste, shrinkage, all
compliance and all expansion KPIs. Excluding them is deliberate: an NL query for
them must return "no grounded data," not a fabricated value.

## Verified queries

```sql
-- Net sales & canonical COGS% by brand
SELECT * FROM SEMANTIC_VIEW(SF_SOLUTIONS.OPS.FRANCHISE_OPS_UNIFIED
  DIMENSIONS stores.brand METRICS txns.net_sales, txns.cogs_pct);

-- Top units by net sales within a brand
SELECT * FROM SEMANTIC_VIEW(SF_SOLUTIONS.OPS.FRANCHISE_OPS_UNIFIED
  DIMENSIONS stores.store_code, stores.brand METRICS txns.net_sales)
ORDER BY net_sales DESC LIMIT 20;
```

## Governance

The view inherits row-access and masking policies from
`references/governance-and-access.md`; the agent queries only this view and
therefore only sees rows the caller's role is entitled to.
