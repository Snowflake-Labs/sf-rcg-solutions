# Operational Runbook — Franchise Operations Intelligence

## Deploy order

Run `scripts/setup.sql` in one pass. If running sections manually:

1. **Cost governance** — resource monitor + warehouse governance first.
2. **Schema remediation** — `BRAND`, 6 tables, LABOR_WEEKLY reconcile.
   **Run as single batch** (session variables `SET pre_cnt/post_cnt`).
3. **Build unified semantic view** — unified governed view.
4. **Dynamic tables** — KPI dynamic tables.
5. **Data metric functions** — DMFs on critical columns.
6. **Alerts** — create `FRANCHISE_OPS_NOTIFY` integration first:
   ```sql
   CREATE NOTIFICATION INTEGRATION IF NOT EXISTS FRANCHISE_OPS_NOTIFY
     TYPE = EMAIL ENABLED = TRUE;
   ```
7. Apply `references/governance-and-access.md` policies.

## Dynamic-table refresh health

```sql
SELECT name, state, target_lag_sec, mean_lag_sec, last_completed_ts
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY())
WHERE name LIKE 'DT_%' ORDER BY last_completed_ts DESC;
```

## DMF / alert triage

Rising `NULL_COUNT` on `TOTAL_AMOUNT`/`TOTAL_FOOD_COST` or nonzero
`DMF_COGS_PCT_OUT_OF_RANGE` = bad loads or broken join — pause reporting
and investigate before trusting COGS%.

## Warehouse sizing

`SF_SOLUTIONS_WH` with `AUTO_SUSPEND=60s` and `RESOURCE_MONITOR=RM_FRANCHISE_OPS`.
Expected ceilings: DTs ~15, alerts ~5, DMFs ~5 credits/month — under 100-credit quota.
If cost climbs, relax `TARGET_LAG` (1h → 4h) before upsizing.

## Schema-remediation rollback

If assertion prints `ABORT: row count drift`:

```sql
USE ROLE SYSADMIN;
CREATE OR REPLACE TABLE SF_SOLUTIONS.OPS.LABOR_WEEKLY
    CLONE SF_SOLUTIONS.OPS.LABOR_WEEKLY_BACKUP;
```

## Grounded-answer discipline

Add regression prompts asking for GAP KPIs and assert the response refuses
and cites the load contract, not a number.
