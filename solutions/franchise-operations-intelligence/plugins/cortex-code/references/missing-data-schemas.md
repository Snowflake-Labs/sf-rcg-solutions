# Missing Data Schemas & Load Contracts

For every ungrounded capability, this is the ingestion contract. The solution
never fabricates — it tells the owner exactly what to load. Table shells are
created by `scripts/setup.sql`; this file specifies what belongs in them.
All targets live in `SF_SOLUTIONS.OPS` with `STORE_ID + BRAND + period` keys.

## Benchmarking

### `STORE_SQUARE_FOOTAGE`
- Grain: store (SCD). Keys: `STORE_ID, EFFECTIVE_DATE`.
- Columns: `SQUARE_FEET`. Load: one-time from real-estate/lease system.

### `CUSTOMER_SATISFACTION`
- Grain: store-survey_date. Columns: `CSAT_SCORE, RESPONSE_COUNT`.
- Load: weekly export from survey vendor → stage → COPY INTO.

## Labor

### Overtime Hours %
- `LABOR_WEEKLY.overtime_hours` exists but may be unreliable. Confirm payroll
  feed populates it post-remediation; if verified → promote to PARTIAL.

### `EMPLOYEE_SEPARATIONS`
- Grain: separation event. Keys: `STORE_ID, EMPLOYEE_ID, SEPARATION_DATE`.
- Columns: `SEPARATION_REASON`. Load: HRIS feed.

## COGS/waste

### `WASTE_LOG`
- Grain: store-week. Keys: `STORE_ID, WEEK_START`.
- Columns: `WASTE_COST, PURCHASES_COST`. Load: inventory system weekly export.

### Shrinkage
- Requires a loss-prevention feed distinguishing waste from theft.
- Do not derive from `variance_pct` alone.

## Compliance — `COMPLIANCE_AUDITS`
- Grain: store-audit_date. Keys: `STORE_ID, AUDIT_DATE`.
- Covers all 4 compliance KPIs: `POINTS_EARNED/POINTS_POSSIBLE`,
  `VIOLATIONS_COUNT`, `CORRECTIVE_ACTIONS/CORRECTIVE_CLOSED`,
  `CHECKLIST_ITEMS_DONE/CHECKLIST_ITEMS_TOTAL`.
- Load: franchisor audit platform export.
- Do NOT use `FRANCHISEE_MASTER.BRAND_COMPLIANCE_SCORE` — org-grain, not unit.

## Expansion — `UNIT_INVESTMENT` + trade-area
- `UNIT_INVESTMENT`: `TOTAL_INVESTED_CAPITAL, EQUITY_INVESTED, BUILDOUT_CAPEX,
  OPEN_DATE`. Enables ROI, payback, cash-on-cash.
- Site-sales projection: needs external trade-area demographics for candidate
  sites. Escalate as Snowflake Marketplace build/buy decision.

## Load pattern (all tables)

1. Stage raw files. 2. `COPY INTO` with `ON_ERROR = ABORT_STATEMENT`.
3. Assert `BRAND IN ('Brand A','Brand B')` and `STORE_ID` resolves against
   `STORE_MASTER`. 4. Re-point skill from GAP to GROUNDED once DMF checks pass.
