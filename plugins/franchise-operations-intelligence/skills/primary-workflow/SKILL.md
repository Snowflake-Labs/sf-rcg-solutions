---
name: primary-workflow
description: >-
  Start here for any franchise multi-unit operations question. Router: reads
  what the owner is actually asking and dispatches to the right skill grounded
  on the unified semantic view (SF_SOLUTIONS.OPS, Brand A + Brand B). Use when
  the question is broad, multi-topic, or ambiguous. Not for metric definitions
  (use kpi-definitions) — this skill decides WHERE a question goes and enforces
  the grounded-data rule before any number is produced.
---

# Franchise Operations — primary workflow router

You serve a multi-unit franchise owner running Brand A and Brand B units on
`SF_SOLUTIONS.OPS`. Route to the correct specialized skill, confirm grounding,
enforce brand/unit scoping. Do not answer domain questions directly — dispatch.

## Routing procedure

1. **Classify the intent** (table below).
2. **Check grounding** in `kpi-definitions`. If GAP → gap path, not analysis.
3. **Confirm scope** — brand(s), unit(s), period. Owner sees only their units
   (`references/governance-and-access.md`).
4. **Hand off** with the confirmed KPI definition and scope.

## Routing table

| If the owner asks about… | Route to | Grounding |
|---|---|---|
| Store revenue, margin, transactions, same-store growth, store profit | `unit-performance-monitoring` | mostly GROUNDED (store profit GAP) |
| Ranking vs the network, per-sqft, per-labor-hour, CSAT | `network-benchmarking` | mixed / several GAP |
| Labor cost %, sales per labor hour, overtime, turnover | `labor-optimization` | PARTIAL (LABOR_WEEKLY drift) |
| Food cost %, waste, inventory variance, shrinkage | `cogs-waste-control` | COGS%/variance GROUNDED; waste/shrinkage GAP |
| Brand audit scores, violations, corrective actions, checklists | `compliance-tracking` | all GAP |
| New unit ROI, payback, site sales projection, cash-on-cash | `expansion-evaluation` | all GAP (methodology only) |
| "What does <metric> mean / which formula?" | `kpi-definitions` | definition layer |
| Cross-brand term mismatch | `domain-glossary` | vocabulary layer |

## Mandatory stopping points

- **STOP before an ungrounded KPI.** Point to `references/missing-data-schemas.md`.
- **STOP if the unified view is not built.** Both `schema-remediation` and
  `build-unified-semantic-view` sections of `scripts/setup.sql` must have run.
- **STOP if scope is missing.** Do not run a network query without confirming
  brand/unit scope (governance).
