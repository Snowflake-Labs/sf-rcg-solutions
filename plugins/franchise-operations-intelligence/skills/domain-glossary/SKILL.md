---
name: domain-glossary
description: >-
  Cross-brand vocabulary reconciliation for the QSR franchise network. Use when
  a term means different things to Brand A vs Brand B, when someone says
  "ticket" but means "net sales", "food cost" but means "COGS", "SSS",
  "daypart", "unit vs store". Maps words to canonical concepts so analytics
  don't silently mix apples and oranges across brands.
---

# Franchise operations domain glossary

Two brands, historically three disconnected app stacks. This glossary reconciles
terms so every skill and the agent speak one language against `SF_SOLUTIONS.OPS`.

## Brand context

- **Brand A** — Mexican QSR, ~500 stores, ~$11 avg ticket.
- **Brand B** — fried-chicken QSR, ~300 stores, ~$18 avg ticket.
- ALWAYS segment by `BRAND` — different ticket sizes and cost structures.

## Canonical term map

| You may hear… | Canonical term | Maps to | Note |
|---|---|---|---|
| ticket, avg check, revenue, sales | **Net Sales** | `TOTAL_AMOUNT` | SUM = net sales; AVG = avg ticket |
| gross sales, pre-tax | **Gross Sales** | `SUBTOTAL` | NOT the COGS% denominator |
| food cost, COGS, product cost | **COGS** | `TOTAL_FOOD_COST` | COGS% = COGS ÷ net sales |
| labor, crew cost, payroll | **Labor Cost** | `LABOR_WEEKLY.total_labor_cost` | Includes benefits |
| prime cost | **Prime Cost** | COGS + Labor | See `references/sql-patterns.md` |
| SSS, comps, same-store | **Same-Store Sales Growth** | prior-year net sales delta | Comp units only |
| store, unit, location | **Unit / Store** | `STORE_MASTER.STORE_ID` | |
| operator, owner, franchisee org | **Franchisee** | `FRANCHISEE_MASTER.FRANCHISEE_ID` | Org-level, not unit |
| daypart | **Daypart** | `POS_TRANSACTIONS.DAYPART` | Breakfast/Lunch/Afternoon/Dinner/Late Night |
| channel, order type | **Order Channel** | `ORDER_CHANNEL` | Drive-Thru/Dine-In/Mobile App/Delivery |

## Key rules

1. Resolve "sales" to Net vs Gross before writing any formula.
2. Never pool brands — ticket sizes differ.
3. `BRAND_COMPLIANCE_SCORE` is org-grain, not per-unit — never substitute for
   audit score (`domain-glossary`: unit vs franchisee grain).
