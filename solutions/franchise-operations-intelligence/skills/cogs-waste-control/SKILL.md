---
name: cogs-waste-control
description: >-
  Protect food-cost margin for a franchise owner: COGS % of sales, inventory
  variance %, waste % of purchases, and shrinkage $ loss across Brand A and
  Brand B units. Use when the owner asks "why is food cost up", "which stores have
  unexplained usage", "where am I losing product to waste or shrinkage", "is my
  variance a recipe problem or a theft problem". Enforces ONE canonical COGS%
  definition network-wide (COGS ÷ net sales), grounds COGS% and inventory
  variance on POS_TRANSACTIONS / FOOD_COST_WEEKLY, and treats waste and
  shrinkage as ungrounded gaps rather than inventing loss figures.
---

# COGS & waste control

Show cost of goods as a percent of sales per unit-week so the owner protects
food-cost margin. This skill's defining job is to enforce **one** COGS%
definition network-wide.

## COGS% canonical definition

Multiple COGS% definitions existed across brand app-stacks, including a variant
dividing by `SUBTOTAL` (gross sales). **Per the ratified canonical definition:**

```
COGS % = SUM(TOTAL_FOOD_COST) / NULLIF(SUM(TOTAL_AMOUNT),0) * 100   -- COGS ÷ NET sales
```

Any report dividing by `SUBTOTAL` is legacy brand-local and must be reconciled.
Full write-up: `references/metric-definitions.md`.

## Metrics this skill owns

| KPI | Formula | Status |
|-----|---------|--------|
| COGS % of Sales | `SUM(TOTAL_FOOD_COST)/NULLIF(SUM(TOTAL_AMOUNT),0)*100` | GROUNDED (canonical) |
| Inventory Variance % | `FOOD_COST_WEEKLY.variance_pct` = `(actual-theoretical)/NULLIF(theoretical,0)*100` | GROUNDED |
| Waste % of Purchases | `waste_cost/NULLIF(purchases,0)*100` | **GAP — no feed** |
| Shrinkage $ Loss | `theoretical_usage - actual_usage` (loss-attributed) | **GAP — no feed** |

## Workflow

1. **Confirm scope** — brand/unit/week (segment by BRAND; cost structures differ).
2. **COGS%** from `POS_TRANSACTIONS` using the canonical denominator:

   ```sql
   SELECT store_id, brand,
          ROUND(SUM(total_food_cost) / NULLIF(SUM(total_amount),0) * 100, 2) AS cogs_pct
   FROM SF_SOLUTIONS.OPS.POS_TRANSACTIONS
   WHERE brand = :brand
   GROUP BY store_id, brand;
   ```

3. **Inventory variance** from `FOOD_COST_WEEKLY.variance_pct` — a positive
   variance means actual food cost exceeds theoretical, i.e. unexplained usage
   (over-portioning, waste, or shrinkage). Use it to flag units for
   investigation, but note it does not by itself distinguish waste from theft.

## Mandatory stopping points — waste & shrinkage

- **Waste % of Purchases** — GAP. Do not derive a waste % from variance. Elicit
  a waste/purchases feed.
- **Shrinkage $ Loss** — GAP. Do not attribute variance to shrinkage without a
  loss-prevention feed.

For both, return the required schema/load contract from
`references/missing-data-schemas.md` instead of a number.

## Alerting

A COGS spike above threshold is surfaced proactively by the condition-gated
serverless alert in `scripts/setup.sql` (alerts section).
