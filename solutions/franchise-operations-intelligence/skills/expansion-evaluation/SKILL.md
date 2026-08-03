---
name: expansion-evaluation
description: >-
  Evaluate new-unit and reinvestment decisions for a franchise owner: unit-level
  ROI %, payback period, projected sales for a candidate site (trade-area
  model), and cash-on-cash return. Use when the owner asks "should I open
  another unit", "what's the payback on this store", "how much would a site at
  this location do", "where should I reinvest capital". IMPORTANT: none of these
  KPIs have grounded financial or trade-area data in the repo — this skill
  provides the pro-forma methodology and the exact external inputs required, and
  escalates the trade-area data purchase as a build/buy decision. It never
  fabricates a projection.
---

# Expansion evaluation

Decide where to reinvest and whether to open new units. **All four KPIs are
ungrounded.** This skill ships the *methodology* and the *required inputs* — not
numbers.

## Grounding status — all GAP

| KPI | Formula (methodology) | Required inputs (missing) |
|-----|-----------------------|---------------------------|
| Unit-Level ROI % | `annual_unit_profit / total_invested_capital * 100` | unit P&L + investment basis |
| Payback Period | `total_investment / annual_unit_cash_flow` | unit cash flow + capex |
| Projected Sales for New Site | trade-area regression on comparable units | trade-area demographics + comparables |
| Cash-on-Cash Return % | `annual_pretax_cash_flow / equity_invested * 100` | unit cash flow + equity invested |

## Workflow — pro-forma methodology (ship now)

1. **State the gap.** No unit P&L, capex, or trade-area data exists in
   `SF_SOLUTIONS.OPS`. Do not produce an ROI, payback, or site projection from
   available POS data alone.
2. **Collect the external inputs** the methodology needs (elicit from the owner /
   franchise development): build-out capex, equity vs financed split, projected
   unit P&L, and — for site projection — trade-area demographics and a set of
   comparable existing units. Target schemas in `references/missing-data-schemas.md`.
3. **Apply the pro-forma** once inputs exist, using the formulas above.

## Escalation — build vs buy

Site-sales projection depends on external trade-area/market data the account
does not own. Recommendation: **ship the pro-forma methodology now; escalate the
Snowflake Marketplace data purchase as a budget decision.**

## Mandatory stopping point

Never return a fabricated ROI, payback, cash-on-cash, or site-sales figure.
Return the methodology and the list of required inputs, and flag the trade-area
data purchase as the gating decision.
