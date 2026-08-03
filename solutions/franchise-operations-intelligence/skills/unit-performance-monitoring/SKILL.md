---
name: unit-performance-monitoring
description: >-
  Monitor unit-level P&L for a multi-unit franchise owner: net sales, gross
  margin %, transaction count, same-store sales growth, and store profit across
  Brand A and Brand B units. Use when the owner asks "which stores are slipping",
  "how did unit X do this month vs last year", "where is margin eroding", "is it
  a traffic problem or a ticket problem", or wants a ranked store scorecard.
  Grounded on V_STORE_PERFORMANCE_SUMMARY / POS_TRANSACTIONS in SF_SOLUTIONS.OPS.
  Handles same-store growth (base grounded, prior-year logic applied) and
  surfaces store profit as an ungrounded gap rather than inventing a number.
---

# Unit performance monitoring

Give the multi-unit owner a trusted read on each store's top line and margin so
they catch a slipping unit before month-end. Grounded on
`SF_SOLUTIONS.OPS.V_STORE_PERFORMANCE_SUMMARY` and `POS_TRANSACTIONS`.

## Metrics this skill owns

| KPI | Formula (canonical, from kpi-definitions) | Status |
|-----|-------------------------------------------|--------|
| Net Sales | `SUM(TOTAL_AMOUNT)` | GROUNDED |
| Gross Margin % | `SUM(GROSS_PROFIT)/NULLIF(SUM(SUBTOTAL),0)*100` | GROUNDED |
| Transaction Count | `COUNT(TRANSACTION_ID)` | GROUNDED |
| Same-Store Sales Growth | prior-year net-sales delta, units open both periods | PARTIAL (apply pattern) |
| EBITDA / Store Profit | store P&L rollup | **GAP — do not invent** |

## Workflow

1. **Confirm scope** — brand(s), unit(s), period. Enforce owner→unit row scoping
   (`references/governance-and-access.md`). Always segment by `BRAND` (Brand A
   ~$11 vs Brand B ~$18 ticket — do not pool).
2. **Pick the grain** — store-day for traffic diagnosis, store-month for trend.
3. **Pull the grounded metrics** from `V_STORE_PERFORMANCE_SUMMARY`:

   ```sql
   SELECT store_code, region,
          net_sales,
          gross_margin_pct,
          total_transactions,
          avg_ticket
   FROM SF_SOLUTIONS.OPS.V_STORE_PERFORMANCE_SUMMARY
   WHERE brand = :brand            -- always scope by brand
   ORDER BY net_sales DESC;
   ```

4. **Traffic vs ticket diagnosis** — if net sales fall, decompose:
   declining `total_transactions` = traffic problem; flat transactions with
   lower `avg_ticket` = ticket/mix problem. State which one explicitly.
5. **Same-Store Sales Growth** — apply the period-over-period pattern in
   `references/sql-patterns.md`, and restrict to units open in BOTH periods
   (a new opening is not a comp store).

## Mandatory stopping point — Store Profit

**EBITDA / Store Profit is a GAP.** There is no store-level P&L modeled.
Do NOT approximate it from gross profit. Respond:

> "Store profit requires a store-level P&L (occupancy, G&A, D&A) that isn't
> modeled yet. I can show gross profit and margin now; the P&L load contract is
> in `references/missing-data-schemas.md`."

## Performance notes

Read from `V_STORE_PERFORMANCE_SUMMARY` or the KPI dynamic tables, never raw
`POS_TRANSACTIONS`, so aggregation pushes down and you stay off the 2M+ row base
table. Refresh health monitored per `references/operational-runbook.md`.
