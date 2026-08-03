---
name: domain-glossary
description: >-
  Cross-brand vocabulary reconciliation for the QSR franchise network. Use when
  a term means different things to Brand A vs Brand B vs corporate QSR reporting,
  when someone says "ticket" but means "net sales", "food cost" but means
  "COGS", "prime cost", "SSS", "daypart", "unit vs store vs location", or when
  two teams are using the same word for different numbers. This is the shared
  lexicon that lets one unified semantic view serve both brands. Not a metric
  formula reference (use kpi-definitions / metric-definitions.md) — this maps
  words to canonical concepts so the analytics don't silently mix apples and
  oranges across brands.
---

# Franchise operations domain glossary

One network, two brands (Brand A, Brand B), historically three disconnected app
stacks with no shared model. Words drifted. This glossary reconciles them so
every skill and the agent speak one language against `SF_SOLUTIONS.OPS`.

## Brand context

- **Brand A** — Mexican QSR, strong late-night, ~500 stores, ~$11 avg ticket.
- **Brand B** — fried-chicken QSR, family-meal focus, ~300 stores, ~$18 avg ticket.
- **BRAND** dimension separates them. ALWAYS filter/segment on `BRAND`; the two
  brands have different ticket sizes and cost structures and must not be pooled
  without segmentation.

## Canonical term map

| You may hear… | Canonical term | Maps to | Note |
|---|---|---|---|
| ticket, avg check, revenue, sales | **Net Sales** | `POS_TRANSACTIONS.TOTAL_AMOUNT` | "Avg ticket" = `AVG(TOTAL_AMOUNT)`; "net sales" = `SUM`. |
| gross sales, pre-tax sales | **Gross Sales** | `SUBTOTAL` | Before tax. Do NOT use as the COGS% denominator. |
| food cost, COGS, product cost | **COGS** | `TOTAL_FOOD_COST` | Canonical COGS% = COGS ÷ **net sales**. |
| labor, crew cost, payroll | **Labor Cost** | `LABOR_WEEKLY.total_labor_cost` | Includes benefits loading. |
| prime cost | **Prime Cost** | COGS + Labor | See `references/sql-patterns.md` prime-cost rollup pattern. |
| SSS, comps, same-store | **Same-Store Sales Growth** | prior-year net sales delta | Units open in both periods only. |
| store, unit, location, restaurant | **Unit / Store** | `STORE_MASTER.STORE_ID` | Use "unit" with the owner; "store" in the data. |
| operator, owner, franchisee org | **Franchisee** | `FRANCHISEE_MASTER.FRANCHISEE_ID` | Org that owns multiple units. |
| daypart | **Daypart** | `POS_TRANSACTIONS.DAYPART` | Breakfast/Lunch/Afternoon/Dinner/Late Night. |
| channel, order type | **Order Channel** | `ORDER_CHANNEL` | Drive-Thru/Dine-In/Mobile App/Delivery. |
| SOS, drive-thru time | **Speed of Service** | `SPEED_OF_SERVICE_SECONDS` | Seconds. |
| tier | **Franchisee Tier** | `FRANCHISEE_MASTER.FRANCHISEE_TIER` | Platinum/Gold/Silver/Bronze. |

## Reconciliation rules

1. **"Sales" is ambiguous — always resolve to Net Sales vs Gross Sales.** COGS%,
   gross margin, and food-cost% each have a specific denominator; do not swap.
2. **Never pool brands.** Brand A (~$11) and Brand B (~$18) ticket sizes differ;
   averages across brands mislead. Segment by `BRAND`.
3. **Unit vs franchisee grain.** `BRAND_COMPLIANCE_SCORE` lives at franchisee-org
   grain, not per-unit — do not present it as a per-store audit score.

Whenever a term is undefined or a source is missing, defer to `kpi-definitions`
for grounding status rather than guessing a mapping.
