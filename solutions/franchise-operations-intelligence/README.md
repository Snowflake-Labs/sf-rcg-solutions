# Franchise Multi-Unit Operations Intelligence

Disclaimer: This application is not part of the Snowflake Service and is governed by the terms in LICENSE, unless expressly agreed to in writing. You use this application at your own risk, and Snowflake has no obligation to support your use of this application. [Learn more](../../LEGAL.md)

> **Industry:** Retail, CPG & General

## Overview

Guided analytics workflows, governed metric definitions, schema remediation scripts, and a
Cortex Agent for franchise multi-unit owners managing unit performance, benchmarking, labor,
COGS/waste, compliance, and expansion across a QSR Brands network (Brand A + Brand B).

Its defining discipline: **it never fabricates a number.** Of the 25 target KPIs, the ones
with real data are grounded and computed against a canonical definition; ungrounded ones are
surfaced as gaps with an exact ingestion contract, not guessed.

## Architecture

1. **Schema remediation** — adds `BRAND` across core tables, backfills from store codes,
   scaffolds six structurally missing tables (square footage, CSAT, separations, waste log,
   compliance audits, unit investment).
2. **Unified semantic view** — `FRANCHISE_OPS_UNIFIED` merges Brand A and Brand B into a
   single governed model with canonical metric definitions.
3. **KPI dynamic tables** — `DT_STORE_MONTH_KPIS` and `DT_SAME_STORE_BASE` refresh
   incrementally on a 1-hour target-lag SLA.
4. **Data quality** — system and custom DMFs monitor freshness, null rates, and COGS%
   plausibility on critical columns.
5. **Alerts** — four serverless, condition-gated alerts fire on COGS spike, labor drift,
   compliance failure, and waste spike.
6. **Cortex Agent** — `franchise-analyst` answers natural-language questions grounded
   strictly on the unified semantic view; refuses to answer ungrounded KPIs.

## Key Snowflake Features

- Semantic View (`FRANCHISE_OPS_UNIFIED`) with governed canonical metrics
- Dynamic Tables (`DT_STORE_MONTH_KPIS`, `DT_SAME_STORE_BASE`) with incremental refresh
- Data Metric Functions (system DMFs + custom `DMF_COGS_PCT_OUT_OF_RANGE`)
- Cortex Agent grounded on a semantic view
- Serverless Alerts (condition-gated, zero compute unless triggered)
- Resource Monitor (`RM_FRANCHISE_OPS`) with staged notify/suspend triggers

## Prerequisites

- Snowflake account (Enterprise edition recommended)
- ACCOUNTADMIN role
- Warehouse: SF_SOLUTIONS_WH (created by setup.sql)
- Notification integration `FRANCHISE_OPS_NOTIFY` before resuming alerts

## Quick Install

Use Cortex Code:

```
$sf-rcg-solutions:franchise-operations-intelligence
```

## Solution Objects

| Object | Type | Description |
|--------|------|-------------|
| SF_SOLUTIONS.OPS.FRANCHISE_OPS_UNIFIED | Semantic View | Unified governed model over Brand A + Brand B |
| SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS | Dynamic Table | Store-month KPIs: net sales, COGS%, gross margin, avg ticket |
| SF_SOLUTIONS.OPS.DT_SAME_STORE_BASE | Dynamic Table | Same-store sales growth vs prior year |
| SF_SOLUTIONS.OPS.DMF_COGS_PCT_OUT_OF_RANGE | Data Metric Function | Flags COGS% outside 5–60% plausible band |
| SF_SOLUTIONS.OPS.ALERT_COGS_SPIKE | Alert | Fires when any unit breaches 35% COGS for the current month |
| SF_SOLUTIONS.OPS.ALERT_LABOR_DRIFT | Alert | Fires when labor cost % exceeds 32% |
| SF_SOLUTIONS.OPS.ALERT_COMPLIANCE_FAILURE | Alert | Fires when brand audit score drops below 80% |
| SF_SOLUTIONS.OPS.ALERT_WASTE_SPIKE | Alert | Fires when waste exceeds 4% of purchases |
| RM_FRANCHISE_OPS | Resource Monitor | 100-credit/month ceiling with staged notify/suspend |

## Canonical Metric Decisions

- **COGS% = COGS ÷ net sales** (resolves a historical three-way conflict across brand app-stacks)
- **Always segment by BRAND** — Brand A (~$11) and Brand B (~$18) ticket sizes must not be pooled
- **Ungrounded KPIs are gaps, not guesses** — each ships a load contract in `references/missing-data-schemas.md`
