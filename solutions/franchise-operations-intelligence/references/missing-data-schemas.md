# Missing Data Schemas & Load Contracts (14 ungrounded capabilities)

Component: `cmp-missing-data-schemas-ref` (solution_design). For every capability
with no grounded source, this is the ingestion contract: target table, grain,
keys, and load pattern. The solution never fabricates these values — it tells the
owner exactly what to load. Table shells are created idempotently by
`scripts/setup.sql`; this file specifies what belongs in them.

All targets live in `SF_SOLUTIONS.OPS` and carry `STORE_ID` + `BRAND` + a period key
so they join the unified view.

## Benchmarking gaps

### Sales per Sq Ft — `STORE_SQUARE_FOOTAGE`
- Grain: store (SCD by `EFFECTIVE_DATE`). Keys: `STORE_ID, EFFECTIVE_DATE`.
- Columns: `SQUARE_FEET`. Load: one-time from real-estate/lease system, then on
  remodel. Once loaded, `network-benchmarking` computes `net_sales / square_feet`.

### CSAT — `CUSTOMER_SATISFACTION`
- Grain: store-survey_date. Columns: `CSAT_SCORE, RESPONSE_COUNT`.
- Load: batch from the survey vendor (e.g., weekly export → stage → COPY INTO).

## Labor gaps

### Overtime Hours %
- `LABOR_WEEKLY.overtime_hours` exists but may be unreliable.
  Contract: confirm the payroll feed populates `overtime_hours`/`actual_hours`
  post-remediation; if verified, promote KPI to PARTIAL. No new table required.

### Employee Turnover — `EMPLOYEE_SEPARATIONS`
- Grain: separation event. Keys: `STORE_ID, EMPLOYEE_ID, SEPARATION_DATE`.
- Columns: `SEPARATION_REASON`. Turnover = separations ÷ avg headcount (headcount
  derivable from `LABOR_WEEKLY` distinct `employee_id`). Load: HRIS feed.

## COGS/waste gaps

### Waste % — `WASTE_LOG`
- Grain: store-week. Keys: `STORE_ID, WEEK_START`.
- Columns: `WASTE_COST, PURCHASES_COST`. Load: inventory system weekly export.

### Shrinkage $ — reuse `WASTE_LOG` + theoretical usage
- Shrinkage = theoretical usage cost − actual usage cost attributable to loss;
  requires a loss-prevention feed distinguishing waste from theft. Do not derive
  from variance alone.

## Compliance gaps — `COMPLIANCE_AUDITS`

- Grain: store-audit_date. Keys: `STORE_ID, AUDIT_DATE`.
- Columns cover all 4 KPIs: `POINTS_EARNED/POINTS_POSSIBLE` (audit score),
  `VIOLATIONS_COUNT`, `CORRECTIVE_ACTIONS/CORRECTIVE_CLOSED` (closure rate),
  `CHECKLIST_ITEMS_DONE/CHECKLIST_ITEMS_TOTAL` (checklist %).
- Load: franchisor audit platform export. Do NOT substitute
  `FRANCHISEE_MASTER.BRAND_COMPLIANCE_SCORE` (org grain, not per-unit).

## Expansion gaps — `UNIT_INVESTMENT` + external trade-area

- `UNIT_INVESTMENT` (grain: store): `TOTAL_INVESTED_CAPITAL, EQUITY_INVESTED,
  BUILDOUT_CAPEX, OPEN_DATE` → enables ROI, payback, cash-on-cash.
- **Site-sales projection** additionally needs external trade-area demographics
  for candidate sites. Ship pro-forma methodology now (`expansion-evaluation`),
  escalate the data purchase as a Snowflake Marketplace decision.

## Load pattern (all tables)

1. Land raw files in an internal stage. 2. `COPY INTO` the target with
   `ON_ERROR = ABORT_STATEMENT`. 3. Assert `BRAND IN ('Brand A','Brand B')` and
   `STORE_ID` FK-resolves against `STORE_MASTER`. 4. Re-point the matching
   skill from GAP to GROUNDED once row counts and DMF checks pass.
