---
name: expansion-evaluation
description: >-
  Evaluate new-unit and reinvestment decisions: unit-level ROI %, payback
  period, projected sales for a candidate site, and cash-on-cash return. Use
  when the owner asks "should I open another unit?", "what's the payback?".
  IMPORTANT: all 4 KPIs are ungrounded — this skill provides methodology and
  required inputs, escalates trade-area data purchase. Never fabricates a
  projection.
---

# Expansion evaluation

All 4 expansion KPIs are ungrounded. This skill ships **methodology + required
inputs** — not numbers.

## Status — all GAP

| KPI | Formula | Required inputs |
|-----|---------|-----------------|
| Unit-Level ROI % | `annual_unit_profit / total_invested_capital * 100` | unit P&L + investment basis |
| Payback Period | `total_investment / annual_unit_cash_flow` | unit cash flow + capex |
| Projected Sales (New Site) | trade-area regression on comps | trade-area demographics + comparables |
| Cash-on-Cash Return % | `annual_pretax_cash_flow / equity_invested * 100` | unit cash flow + equity |

## Workflow

1. **State the gap** — no unit P&L, capex, or trade-area data in `SF_SOLUTIONS.OPS`.
2. **Collect inputs** from the owner: capex, equity/financed split, projected P&L,
   and trade-area characteristics. Target schemas: `references/missing-data-schemas.md`.
3. **Apply pro-forma** once inputs exist.

## Escalation

Site-sales projection needs external trade-area data. Recommendation: ship the
pro-forma methodology now; escalate the Snowflake Marketplace data purchase as a
budget decision.

Never return a fabricated projection.
