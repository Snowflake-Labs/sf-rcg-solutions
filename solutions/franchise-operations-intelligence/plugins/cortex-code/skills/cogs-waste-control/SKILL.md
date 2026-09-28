---
name: cogs-waste-control
description: >-
  Protect food-cost margin: COGS % of sales, inventory variance %, waste % of
  purchases, and shrinkage $ loss across Brand A and Brand B. Enforces ONE
  canonical COGS% definition network-wide (COGS ÷ net sales), grounds COGS%
  and inventory variance on POS_TRANSACTIONS / FOOD_COST_WEEKLY, and treats
  waste and shrinkage as ungrounded gaps.
---

# COGS & waste control

Show cost of goods as a percent of sales per unit-week. Core job: enforce one
COGS% definition network-wide.

## Canonical COGS% definition

```
COGS % = SUM(TOTAL_FOOD_COST) / NULLIF(SUM(TOTAL_AMOUNT),0) * 100   -- COGS ÷ NET sales
```

Any variant dividing by `SUBTOTAL` is legacy brand-local. Full write-up:
`references/metric-definitions.md`.

## Metrics

| KPI | Status |
|-----|--------|
| COGS % of Sales (canonical) | GROUNDED |
| Inventory Variance % (`FOOD_COST_WEEKLY.variance_pct`) | GROUNDED |
| Waste % of Purchases | **GAP** |
| Shrinkage $ Loss | **GAP** |

## Workflow

```sql
SELECT store_id, brand,
       ROUND(SUM(total_food_cost) / NULLIF(SUM(total_amount),0) * 100, 2) AS cogs_pct
FROM SF_SOLUTIONS.OPS.POS_TRANSACTIONS
WHERE brand = :brand GROUP BY store_id, brand;
```

Positive `variance_pct` = actual food cost > theoretical (over-portioning, waste,
or shrinkage). Does not by itself distinguish waste from theft.

## Stopping points

- **Waste %** — GAP. Do not derive from variance. Elicit waste/purchases feed.
- **Shrinkage** — GAP. Requires a loss-prevention feed. Load contract:
  `references/missing-data-schemas.md`.

A COGS spike alert is pre-wired in `scripts/setup.sql` (alerts section).
