# Operational Runbook — Franchise Operations Intelligence

Component: `cmp-operational-runbook-ref` (solution_design, pillar
platform_governance). Day-2 operations: refresh monitoring, DMF/alert triage,
warehouse sizing, cost controls, and the schema-remediation rollback procedure.
WAF: operational_excellence + cost_optimization + reliability.

## Deploy order (must be followed)

The `scripts/setup.sql` file merges all scripts in the correct order. If running
sections manually, follow this sequence:

1. Cost governance section — resource monitor + warehouse governance first.
2. Schema remediation section — BRAND, 6 tables, LABOR_WEEKLY reconcile
   (additive/idempotent; safe to re-run). **Run as a single batch** (session variables).
3. Build unified semantic view section — unified governed view.
4. Dynamic tables section — KPI dynamic tables.
5. Data metric functions section — DMFs on critical columns.
6. Alerts section — condition-gated alerts (requires notification integration
   `FRANCHISE_OPS_NOTIFY`; create it before resuming alerts):
   ```sql
   CREATE NOTIFICATION INTEGRATION IF NOT EXISTS FRANCHISE_OPS_NOTIFY
     TYPE = EMAIL
     ENABLED = TRUE;
   ```
7. Apply `references/governance-and-access.md` policies.

## Dynamic-table refresh health

Monitor lag/failures on `DT_STORE_MONTH_KPIS` and `DT_SAME_STORE_BASE`:

```sql
SELECT name, state, refresh_action, target_lag_sec, mean_lag_sec,
       maximum_lag_sec, last_completed_ts
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY())
WHERE name LIKE 'DT_%'
ORDER BY last_completed_ts DESC;
```

Recommended DT-health alert: fire when any DT's `mean_lag_sec` exceeds its
`target_lag_sec` or `state <> 'ACTIVE'`.

## DMF / alert triage

- DMF results: `SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS`. A rising
  `NULL_COUNT` on `TOTAL_AMOUNT`/`TOTAL_FOOD_COST` or a nonzero
  `DMF_COGS_PCT_OUT_OF_RANGE` count means bad loads or a broken join — pause
  downstream reporting and investigate the source load before trusting COGS%.
- Alert firing: check the condition query in the alerts section of setup.sql,
  confirm it is a real breach (not a data-quality artifact per the DMFs), then
  action the unit.

## Warehouse sizing & cost controls

- Warehouse `SF_SOLUTIONS_WH` is managed by the shared SF_SOLUTIONS infrastructure
  with `AUTO_SUSPEND=60s` and `AUTO_RESUME=TRUE`.
- Resource monitor `RM_FRANCHISE_OPS`: 100 credits/month, notify at 75%/90%,
  suspend at 100%. Expected serverless ceilings (DTs ~15, alerts ~5, DMFs ~5
  credits/mo) sit well under quota.
- If refresh cost climbs, first relax `TARGET_LAG` (e.g. 1h → 4h) before upsizing.

## Schema-remediation rollback

The schema-remediation section is additive/idempotent, and the LABOR_WEEKLY
reconcile is guarded by a pre/post row-count assertion against a zero-copy backup.
If the assertion prints `ABORT: row count drift`:

```sql
USE ROLE SYSADMIN;
CREATE OR REPLACE TABLE SF_SOLUTIONS.OPS.LABOR_WEEKLY
    CLONE SF_SOLUTIONS.OPS.LABOR_WEEKLY_BACKUP;   -- instant, zero-copy restore
```

Column additions (`ADD COLUMN IF NOT EXISTS`) and `CREATE TABLE IF NOT EXISTS`
are non-destructive; re-running the script converges without data loss.

## Grounded-answer discipline

Ungrounded skills and the agent must return a "no grounded data" signal for GAP
KPIs (see each skill's stopping point). Add regression prompts that ask for a
GAP KPI (e.g. "what's my brand audit score") and assert the response refuses and
cites the load contract, not a number.
