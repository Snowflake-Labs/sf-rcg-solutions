---
name: unit-performance-monitoring
description: >-
  Monitor unit-level P&L: net sales, gross margin %, transaction count,
  same-store sales growth, and store profit across Brand A and Brand B. Use
  when the owner asks "which stores are slipping", "is it a traffic or ticket
  problem", or wants a ranked store scorecard. Surfaces store profit as an
  ungrounded gap rather than inventing a number.
---

# Unit performance monitoring

Trusted read on each store's top line and margin — catch a slipping unit before
month-end. Grounded on `SF_SOLUTIONS.OPS.V_STORE_PERFORMANCE_SUMMARY`.

## Metrics

| KPI | Formula | Status |
|-----|---------|--------|
| Net Sales | `SUM(TOTAL_AMOUNT)` | GROUNDED |
| Gross Margin % | `SUM(GROSS_PROFIT)/NULLIF(SUM(SUBTOTAL),0)*100` | GROUNDED |
| Transaction Count | `COUNT(TRANSACTION_ID)` | GROUNDED |
| Same-Store Sales Growth | prior-year delta, comp units only | PARTIAL |
| EBITDA / Store Profit | store P&L rollup | **GAP — do not invent** |

## Workflow

1. Confirm scope — brand, unit, period. Always segment by `BRAND`.
2. Pull from `V_STORE_PERFORMANCE_SUMMARY`:
   ```sql
   SELECT store_code, region, net_sales, gross_margin_pct, total_transactions, avg_ticket
   FROM SF_SOLUTIONS.OPS.V_STORE_PERFORMANCE_SUMMARY
   WHERE brand = :brand ORDER BY net_sales DESC;
   ```
3. Traffic vs ticket — declining `total_transactions` = traffic; flat transactions
   with lower `avg_ticket` = ticket/mix. State which one.
4. SSS — apply the period-over-period pattern in `references/sql-patterns.md`;
   restrict to units open in BOTH periods.

## Stopping point — Store Profit

**EBITDA / Store Profit is a GAP.** Do NOT approximate from gross profit.
> "Store profit requires a store-level P&L that isn't modeled yet. I can show
> gross profit and margin now; load contract: `references/missing-data-schemas.md`."

Read from `V_STORE_PERFORMANCE_SUMMARY` or KPI dynamic tables — never raw
`POS_TRANSACTIONS` for aggregates.
