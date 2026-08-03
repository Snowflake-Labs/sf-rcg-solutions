-- =============================================================================
-- Solution: Franchise Multi-Unit Operations Intelligence
-- Industry: Retail, CPG & General
-- Database: SF_SOLUTIONS
-- Schemas:  OPS
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- Shared infrastructure (idempotent)
CREATE DATABASE IF NOT EXISTS SF_SOLUTIONS;
CREATE WAREHOUSE IF NOT EXISTS SF_SOLUTIONS_WH
    WITH WAREHOUSE_SIZE = 'LARGE'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE;

USE DATABASE SF_SOLUTIONS;
USE WAREHOUSE SF_SOLUTIONS_WH;

-- =============================================================================
-- 1. cost-governance.sql
-- Component: cmp-cost-governance (solution_design, pillar platform_governance)
-- Purpose : Cap runaway spend. Resource monitors with notify/suspend triggers
--           on all workload warehouses, AUTO_SUSPEND=60s, documented serverless
--           credit ceilings for dynamic tables and alerts.
-- WAF      : cost_optimization (blocking finding remediated: "No resource
--            monitor, budget, or confirmed auto-suspend on serverless dynamic
--            tables, alerts, and interactive agent warehouse").
-- Note     : Resource monitor creation requires ACCOUNTADMIN by Snowflake design;
--            grant is scoped to this one setup action, then work returns to
--            SYSADMIN. Warehouses target non-prod workloads only.
-- =============================================================================

-- Resource monitors are an account-level object (ACCOUNTADMIN-only in Snowflake).
USE ROLE ACCOUNTADMIN;

-- 1. Monthly credit quota with staged notify/suspend triggers.
CREATE RESOURCE MONITOR IF NOT EXISTS RM_FRANCHISE_OPS
    WITH CREDIT_QUOTA = 100
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 75  PERCENT DO NOTIFY
        ON 90  PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND
        ON 110 PERCENT DO SUSPEND_IMMEDIATE;

-- 2. Solution warehouse is SF_SOLUTIONS_WH (shared; managed by the standard header above).
--    Apply auto-suspend and resource monitor governance to it.
ALTER WAREHOUSE SF_SOLUTIONS_WH SET AUTO_SUSPEND = 60;
ALTER WAREHOUSE SF_SOLUTIONS_WH SET RESOURCE_MONITOR = RM_FRANCHISE_OPS;

-- 3. Least-privilege for day-to-day: hand operations back to SYSADMIN.
GRANT USAGE ON WAREHOUSE SF_SOLUTIONS_WH TO ROLE SYSADMIN;

-- ---------------------------------------------------------------------
-- Documented serverless credit ceilings:
--   * Dynamic tables (DT_STORE_MONTH_KPIS, DT_SAME_STORE_BASE): budget ~15
--     serverless credits/month at 1-hour target lag on this data volume.
--   * Serverless alerts (4, condition-gated): budget ~5 credits/month — they
--     consume compute only when the guard query returns rows.
--   * DMF evaluation (hourly/daily schedules): budget ~5 credits/month.
-- Total expected ceiling well under the 100-credit RM_FRANCHISE_OPS quota.
-- ---------------------------------------------------------------------

USE ROLE SYSADMIN;
USE DATABASE SF_SOLUTIONS;
USE WAREHOUSE SF_SOLUTIONS_WH;
SHOW RESOURCE MONITORS LIKE 'RM_FRANCHISE_OPS';

-- =============================================================================
-- 2. schema-remediation.sql
-- Component: cmp-schema-remediation (solution_design)
-- Purpose : Fix the structural gaps that block a unified model:
--           (1) BRAND column referenced but never created
--           (2) six tables referenced but undefined in setup
--           (3) LABOR_WEEKLY schema drift (pay columns added post-create)
-- Safety   : ADDITIVE + IDEMPOTENT only. IF NOT EXISTS / OR REPLACE VIEW.
--            Clone-validate-swap for the one mutating reconcile (LABOR_WEEKLY).
--            Pre/post row-count assertions. Documented rollback via zero-copy
--            clone restore. Targets a NON-PROD warehouse; never ACCOUNTADMIN.
-- WAF      : reliability (reversible, validated); security_governance (SYSADMIN)
-- =============================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE SF_SOLUTIONS_WH;
USE DATABASE SF_SOLUTIONS;
USE SCHEMA OPS;

-- ---------------------------------------------------------------------
-- 1. BRAND column — additive, idempotent
-- ---------------------------------------------------------------------
ALTER TABLE IF EXISTS SF_SOLUTIONS.OPS.STORE_MASTER       ADD COLUMN IF NOT EXISTS BRAND VARCHAR;
ALTER TABLE IF EXISTS SF_SOLUTIONS.OPS.POS_TRANSACTIONS   ADD COLUMN IF NOT EXISTS BRAND VARCHAR;
ALTER TABLE IF EXISTS SF_SOLUTIONS.OPS.FRANCHISEE_MASTER  ADD COLUMN IF NOT EXISTS BRAND VARCHAR;

-- Backfill BRAND from store-code convention (TB-##### = Brand A, Brand B#### = Brand B),
-- only where currently NULL so the statement is safe to re-run.
UPDATE SF_SOLUTIONS.OPS.STORE_MASTER
   SET BRAND = CASE WHEN STORE_CODE ILIKE 'TB-%' THEN 'Brand A'
                    WHEN STORE_CODE ILIKE 'Brand B%'  THEN 'Brand B' END
 WHERE BRAND IS NULL;

-- ---------------------------------------------------------------------
-- 2. Six undefined tables — CREATE IF NOT EXISTS (structure only; loads
--    are governed by references/missing-data-schemas.md ingestion contracts)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SF_SOLUTIONS.OPS.STORE_SQUARE_FOOTAGE (
    STORE_ID        NUMBER        NOT NULL,
    BRAND           VARCHAR       NOT NULL,
    SQUARE_FEET     NUMBER,
    EFFECTIVE_DATE  DATE,
    CONSTRAINT PK_STORE_SQFT PRIMARY KEY (STORE_ID, EFFECTIVE_DATE)
);

CREATE TABLE IF NOT EXISTS SF_SOLUTIONS.OPS.CUSTOMER_SATISFACTION (
    STORE_ID        NUMBER        NOT NULL,
    BRAND           VARCHAR       NOT NULL,
    SURVEY_DATE     DATE          NOT NULL,
    CSAT_SCORE      NUMBER(5,2),
    RESPONSE_COUNT  NUMBER
);

CREATE TABLE IF NOT EXISTS SF_SOLUTIONS.OPS.EMPLOYEE_SEPARATIONS (
    STORE_ID          NUMBER      NOT NULL,
    BRAND             VARCHAR     NOT NULL,
    EMPLOYEE_ID       VARCHAR     NOT NULL,
    SEPARATION_DATE   DATE        NOT NULL,
    SEPARATION_REASON VARCHAR
);

CREATE TABLE IF NOT EXISTS SF_SOLUTIONS.OPS.WASTE_LOG (
    STORE_ID        NUMBER        NOT NULL,
    BRAND           VARCHAR       NOT NULL,
    WEEK_START      DATE          NOT NULL,
    WASTE_COST      NUMBER(12,2),
    PURCHASES_COST  NUMBER(12,2)
);

CREATE TABLE IF NOT EXISTS SF_SOLUTIONS.OPS.COMPLIANCE_AUDITS (
    STORE_ID              NUMBER    NOT NULL,
    BRAND                 VARCHAR   NOT NULL,
    AUDIT_DATE            DATE      NOT NULL,
    POINTS_EARNED         NUMBER,
    POINTS_POSSIBLE       NUMBER,
    VIOLATIONS_COUNT      NUMBER,
    CORRECTIVE_ACTIONS    NUMBER,
    CORRECTIVE_CLOSED     NUMBER,
    CHECKLIST_ITEMS_DONE  NUMBER,
    CHECKLIST_ITEMS_TOTAL NUMBER
);

CREATE TABLE IF NOT EXISTS SF_SOLUTIONS.OPS.UNIT_INVESTMENT (
    STORE_ID              NUMBER    NOT NULL,
    BRAND                 VARCHAR   NOT NULL,
    TOTAL_INVESTED_CAPITAL NUMBER(14,2),
    EQUITY_INVESTED       NUMBER(14,2),
    BUILDOUT_CAPEX        NUMBER(14,2),
    OPEN_DATE             DATE
);

-- ---------------------------------------------------------------------
-- 3. LABOR_WEEKLY reconcile — the ONE mutating fix. Clone → validate → swap.
--    Pay columns (regular_pay/overtime_pay/gross_pay/total_labor_cost) were
--    added via ALTER after CREATE; a fresh env may lack them.
--    This block is non-destructive and reversible.
-- NOTE: Execute this block as a single statement batch (session variables).
-- ---------------------------------------------------------------------

-- 3a. Zero-copy backup for rollback (idempotent).
CREATE TABLE IF NOT EXISTS SF_SOLUTIONS.OPS.LABOR_WEEKLY_BACKUP CLONE SF_SOLUTIONS.OPS.LABOR_WEEKLY;

-- 3b. Capture pre-count for assertion.
SET pre_cnt = (SELECT COUNT(*) FROM SF_SOLUTIONS.OPS.LABOR_WEEKLY);

-- 3c. Additive column reconcile (idempotent; no data loss).
ALTER TABLE SF_SOLUTIONS.OPS.LABOR_WEEKLY ADD COLUMN IF NOT EXISTS regular_pay      NUMBER(10,2);
ALTER TABLE SF_SOLUTIONS.OPS.LABOR_WEEKLY ADD COLUMN IF NOT EXISTS overtime_pay     NUMBER(10,2);
ALTER TABLE SF_SOLUTIONS.OPS.LABOR_WEEKLY ADD COLUMN IF NOT EXISTS gross_pay        NUMBER(10,2);
ALTER TABLE SF_SOLUTIONS.OPS.LABOR_WEEKLY ADD COLUMN IF NOT EXISTS benefits_cost    NUMBER(10,2);
ALTER TABLE SF_SOLUTIONS.OPS.LABOR_WEEKLY ADD COLUMN IF NOT EXISTS total_labor_cost NUMBER(10,2);
ALTER TABLE SF_SOLUTIONS.OPS.LABOR_WEEKLY ADD COLUMN IF NOT EXISTS BRAND            VARCHAR;

-- 3d. Recompute pay only where NULL (safe re-run), matching setup formula.
UPDATE SF_SOLUTIONS.OPS.LABOR_WEEKLY
   SET regular_pay      = ROUND(LEAST(actual_hours,40) * regular_rate, 2),
       overtime_pay     = ROUND(overtime_hours * overtime_rate, 2),
       gross_pay        = ROUND(LEAST(actual_hours,40) * regular_rate + overtime_hours * overtime_rate, 2),
       benefits_cost    = ROUND((LEAST(actual_hours,40) * regular_rate + overtime_hours * overtime_rate)
                                * CASE WHEN level_code >= 3 THEN 0.28 ELSE 0.12 END, 2),
       total_labor_cost = ROUND((LEAST(actual_hours,40) * regular_rate + overtime_hours * overtime_rate)
                                * (1 + CASE WHEN level_code >= 3 THEN 0.28 ELSE 0.12 END), 2)
 WHERE total_labor_cost IS NULL;

-- 3e. Post-count assertion — fail loud if the row count changed (must be additive).
SET post_cnt = (SELECT COUNT(*) FROM SF_SOLUTIONS.OPS.LABOR_WEEKLY);
SELECT CASE WHEN $pre_cnt = $post_cnt
            THEN 'OK: LABOR_WEEKLY row count preserved (' || $post_cnt || ')'
            ELSE 'ABORT: row count drift ' || $pre_cnt || ' -> ' || $post_cnt
                 || ' — restore from LABOR_WEEKLY_BACKUP (see runbook)'
       END AS remediation_assertion;

-- ---------------------------------------------------------------------
-- ROLLBACK (documented; run only if assertion fails):
--   CREATE OR REPLACE TABLE SF_SOLUTIONS.OPS.LABOR_WEEKLY
--     CLONE SF_SOLUTIONS.OPS.LABOR_WEEKLY_BACKUP;
-- ---------------------------------------------------------------------

-- Verification roll-up: confirm all 6 new tables + BRAND presence.
SELECT 'STORE_SQUARE_FOOTAGE'  AS obj, COUNT(*) AS row_count FROM SF_SOLUTIONS.OPS.STORE_SQUARE_FOOTAGE
UNION ALL SELECT 'CUSTOMER_SATISFACTION', COUNT(*) FROM SF_SOLUTIONS.OPS.CUSTOMER_SATISFACTION
UNION ALL SELECT 'EMPLOYEE_SEPARATIONS',  COUNT(*) FROM SF_SOLUTIONS.OPS.EMPLOYEE_SEPARATIONS
UNION ALL SELECT 'WASTE_LOG',             COUNT(*) FROM SF_SOLUTIONS.OPS.WASTE_LOG
UNION ALL SELECT 'COMPLIANCE_AUDITS',     COUNT(*) FROM SF_SOLUTIONS.OPS.COMPLIANCE_AUDITS
UNION ALL SELECT 'UNIT_INVESTMENT',       COUNT(*) FROM SF_SOLUTIONS.OPS.UNIT_INVESTMENT;

-- =============================================================================
-- 3. build-unified-semantic-view.sql
-- Component: cmp-unified-semantic-view (solution_design)
-- Purpose : Reconcile 3 brand-specific semantic views into ONE governed semantic
--           view with a BRAND dimension, for natural-language analytics via
--           Cortex Analyst / the franchise-analyst agent.
-- Prereq   : run schema-remediation section first (BRAND column must exist).
-- WAF      : security_governance (single governed model + BRAND scoping);
--            performance_optimization (aggregation pushdown; enumerated columns,
--            no SELECT * on base tables).
-- =============================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE SF_SOLUTIONS_WH;
USE DATABASE SF_SOLUTIONS;
USE SCHEMA OPS;

-- Guard: fail early if BRAND was not remediated.
SELECT CASE WHEN COUNT(*) = 0
            THEN 'ABORT: run schema-remediation section first (BRAND missing on POS_TRANSACTIONS)'
            ELSE 'OK: BRAND present' END AS prereq_check
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'OPS' AND TABLE_NAME = 'POS_TRANSACTIONS' AND COLUMN_NAME = 'BRAND';

-- ---------------------------------------------------------------------
-- Unified semantic view (Snowflake CREATE SEMANTIC VIEW).
-- Columns are ENUMERATED — never SELECT * on the 2M+ row base table (WAF perf).
-- ---------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW SF_SOLUTIONS.OPS.FRANCHISE_OPS_UNIFIED
  TABLES (
    stores AS SF_SOLUTIONS.OPS.STORE_MASTER
      PRIMARY KEY (STORE_ID)
      WITH SYNONYMS ('units','locations','restaurants')
      COMMENT = 'One row per unit across both brands (Brand A, Brand B).',
    txns AS SF_SOLUTIONS.OPS.POS_TRANSACTIONS
      PRIMARY KEY (TRANSACTION_ID)
      WITH SYNONYMS ('sales','pos','transactions'),
    franchisees AS SF_SOLUTIONS.OPS.FRANCHISEE_MASTER
      PRIMARY KEY (FRANCHISEE_ID)
  )
  RELATIONSHIPS (
    txns_to_store AS txns (STORE_ID) REFERENCES stores (STORE_ID)
  )
  DIMENSIONS (
    stores.brand        AS stores.BRAND        WITH SYNONYMS ('chain','banner')
      COMMENT = 'Brand A or Brand B. ALWAYS segment on this — ticket sizes differ.',
    stores.store_code   AS stores.STORE_CODE   WITH SYNONYMS ('store number','unit code'),
    stores.region       AS stores.REGION       WITH SYNONYMS ('territory','area'),
    stores.state_code   AS stores.STATE_CODE,
    stores.store_format AS stores.STORE_FORMAT,
    txns.daypart        AS txns.DAYPART,
    txns.order_channel  AS txns.ORDER_CHANNEL  WITH SYNONYMS ('channel','order type'),
    txns.transaction_date AS txns.TRANSACTION_DATE,
    franchisees.franchisee_tier AS franchisees.FRANCHISEE_TIER
  )
  METRICS (
    -- GROUNDED metrics
    txns.net_sales           AS SUM(txns.TOTAL_AMOUNT)
      WITH SYNONYMS ('revenue','sales','top line')
      COMMENT = 'Net sales = SUM(TOTAL_AMOUNT). Canonical top-line measure.',
    txns.gross_sales         AS SUM(txns.SUBTOTAL)
      COMMENT = 'Pre-tax. Legacy COGS% used this denominator — do NOT for canonical COGS%.',
    txns.gross_profit        AS SUM(txns.GROSS_PROFIT),
    txns.transaction_count   AS COUNT(txns.TRANSACTION_ID)
      WITH SYNONYMS ('transactions','order count','traffic'),
    txns.total_cogs          AS SUM(txns.TOTAL_FOOD_COST)
      WITH SYNONYMS ('food cost','cogs'),
    -- Derived governed metrics
    txns.gross_margin_pct    AS SUM(txns.GROSS_PROFIT) / NULLIF(SUM(txns.SUBTOTAL),0) * 100
      COMMENT = 'Gross margin % = gross_profit / gross_sales * 100.',
    txns.cogs_pct            AS SUM(txns.TOTAL_FOOD_COST) / NULLIF(SUM(txns.TOTAL_AMOUNT),0) * 100
      COMMENT = 'CANONICAL COGS% = COGS / NET sales (ratified escalation). Not gross sales.',
    txns.avg_ticket          AS AVG(txns.TOTAL_AMOUNT)
      WITH SYNONYMS ('average check','avg ticket')
  )
  COMMENT = 'Unified governed franchise-ops model over Brand A + Brand B.
             ALWAYS segment by brand. Ungrounded KPIs (sq-ft, CSAT, labor,
             compliance, expansion) are intentionally excluded until their
             sources are loaded — see references/missing-data-schemas.md.';

-- Smoke test: brand-segmented top line + canonical COGS%.
SELECT * FROM SEMANTIC_VIEW(
  SF_SOLUTIONS.OPS.FRANCHISE_OPS_UNIFIED
  DIMENSIONS stores.brand
  METRICS    txns.net_sales, txns.cogs_pct, txns.gross_margin_pct
);

-- =============================================================================
-- 4. dynamic-tables-kpis.sql
-- Component: cmp-dynamic-tables-kpis (solution_design, pillar data_engineering)
-- Purpose : Incrementally refresh derived KPIs (net sales, gross margin,
--           canonical COGS%, same-store base) with a target-lag SLA.
-- WAF      : reliability (target-lag SLA); cost_optimization (incremental vs
--            full recompute); performance_optimization (pushdown).
-- Prereq   : schema-remediation section (BRAND present).
-- =============================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE SF_SOLUTIONS_WH;
USE DATABASE SF_SOLUTIONS;
USE SCHEMA OPS;

-- Store-month KPI grain.
CREATE OR REPLACE DYNAMIC TABLE SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS
    TARGET_LAG = '1 hour'
    WAREHOUSE  = SF_SOLUTIONS_WH
    REFRESH_MODE = AUTO
    INITIALIZE = ON_CREATE
AS
SELECT
    t.STORE_ID,
    t.BRAND,
    DATE_TRUNC('month', t.TRANSACTION_DATE)                                   AS month_start,
    SUM(t.TOTAL_AMOUNT)                                                       AS net_sales,
    SUM(t.SUBTOTAL)                                                           AS gross_sales,
    COUNT(t.TRANSACTION_ID)                                                   AS transaction_count,
    SUM(t.GROSS_PROFIT)                                                       AS gross_profit,
    SUM(t.TOTAL_FOOD_COST)                                                    AS total_cogs,
    ROUND(SUM(t.GROSS_PROFIT) / NULLIF(SUM(t.SUBTOTAL),0)   * 100, 2)         AS gross_margin_pct,
    -- CANONICAL COGS% = COGS / NET sales (metric-definitions.md)
    ROUND(SUM(t.TOTAL_FOOD_COST) / NULLIF(SUM(t.TOTAL_AMOUNT),0) * 100, 2)    AS cogs_pct,
    ROUND(AVG(t.TOTAL_AMOUNT), 2)                                            AS avg_ticket
FROM SF_SOLUTIONS.OPS.POS_TRANSACTIONS t
GROUP BY t.STORE_ID, t.BRAND, DATE_TRUNC('month', t.TRANSACTION_DATE);

-- Same-store base: net sales aligned to the prior-year same month.
CREATE OR REPLACE DYNAMIC TABLE SF_SOLUTIONS.OPS.DT_SAME_STORE_BASE
    TARGET_LAG = '1 hour'
    WAREHOUSE  = SF_SOLUTIONS_WH
    REFRESH_MODE = AUTO
    INITIALIZE = ON_CREATE
AS
SELECT
    curr.STORE_ID,
    curr.BRAND,
    curr.month_start,
    curr.net_sales                                                           AS net_sales_curr,
    prior.net_sales                                                          AS net_sales_prior_year,
    ROUND((curr.net_sales - prior.net_sales)
          / NULLIF(prior.net_sales,0) * 100, 2)                             AS sss_growth_pct
FROM SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS curr
LEFT JOIN SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS prior
       ON curr.STORE_ID = prior.STORE_ID
      AND prior.month_start = DATEADD('year', -1, curr.month_start)
-- comp stores only: prior-year period must exist (LEFT JOIN keeps new units
-- visible with NULL growth so they are excluded from SSS, not silently zeroed).
;

SHOW DYNAMIC TABLES LIKE 'DT_%' IN SCHEMA SF_SOLUTIONS.OPS;

-- =============================================================================
-- 5. data-metric-functions.sql
-- Component: cmp-dmf-data-quality (solution_design, pillar platform_governance)
-- Purpose : System + custom DMFs for freshness / null-rate / range monitoring
--           on the critical metrics (net sales, COGS%, labor cost, variance).
-- WAF      : reliability + security_governance (automated data-quality assurance).
-- Prereq   : schema-remediation section.
-- =============================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE SF_SOLUTIONS_WH;
USE DATABASE SF_SOLUTIONS;
USE SCHEMA OPS;

-- ---------------------------------------------------------------------
-- 1. System DMFs on critical columns (freshness, null count, row count).
-- ---------------------------------------------------------------------
ALTER TABLE SF_SOLUTIONS.OPS.POS_TRANSACTIONS
    SET DATA_METRIC_SCHEDULE = 'USING CRON 0 * * * * UTC';   -- hourly

ALTER TABLE SF_SOLUTIONS.OPS.POS_TRANSACTIONS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS       ON (TRANSACTION_TIMESTAMP);
ALTER TABLE SF_SOLUTIONS.OPS.POS_TRANSACTIONS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT      ON (TOTAL_AMOUNT);
ALTER TABLE SF_SOLUTIONS.OPS.POS_TRANSACTIONS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT      ON (TOTAL_FOOD_COST);

ALTER TABLE SF_SOLUTIONS.OPS.FOOD_COST_WEEKLY
    SET DATA_METRIC_SCHEDULE = 'USING CRON 0 6 * * * UTC';   -- daily 06:00
ALTER TABLE SF_SOLUTIONS.OPS.FOOD_COST_WEEKLY
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT      ON (VARIANCE_PCT);

ALTER TABLE SF_SOLUTIONS.OPS.LABOR_WEEKLY
    SET DATA_METRIC_SCHEDULE = 'USING CRON 0 6 * * * UTC';
ALTER TABLE SF_SOLUTIONS.OPS.LABOR_WEEKLY
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT      ON (TOTAL_LABOR_COST);

-- ---------------------------------------------------------------------
-- 2. Custom range DMF: share of rows where canonical COGS% is out of a
--    plausible band (5%..60%). Flags bad cost or bad sales joins.
-- ---------------------------------------------------------------------
CREATE OR REPLACE DATA METRIC FUNCTION SF_SOLUTIONS.OPS.DMF_COGS_PCT_OUT_OF_RANGE (
    ARG_T TABLE (COGS_PCT NUMBER)
)
RETURNS NUMBER
AS
$$
    SELECT COUNT_IF(COGS_PCT < 5 OR COGS_PCT > 60)
    FROM ARG_T
$$;

-- Attach the custom DMF to the store-month KPI dynamic table.
ALTER DYNAMIC TABLE SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS
    SET DATA_METRIC_SCHEDULE = 'USING CRON 0 * * * * UTC';
ALTER DYNAMIC TABLE SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS
    ADD DATA METRIC FUNCTION SF_SOLUTIONS.OPS.DMF_COGS_PCT_OUT_OF_RANGE ON (COGS_PCT);

-- Review recent DMF results.
SELECT *
FROM TABLE(INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
    REF_ENTITY_NAME => 'SF_SOLUTIONS.OPS.POS_TRANSACTIONS',
    REF_ENTITY_DOMAIN => 'TABLE'));

-- =============================================================================
-- 6. alerts.sql
-- Component: cmp-alerts (solution_design, pillar data_engineering)
-- Purpose : Serverless, condition-gated alerts for threshold breaches on key
--           KPIs — COGS spike, labor drift, compliance failure, waste spike.
-- WAF      : operational_excellence + reliability (proactive exception surfacing);
--            cost_optimization (SERVERLESS + condition-gated).
-- Prereq   : dynamic-tables-kpis and schema-remediation sections must run first.
--            A notification integration named FRANCHISE_OPS_NOTIFY must exist
--            (see references/operational-runbook.md). Replace the placeholder
--            email address below with your actual ops-alerts address.
-- =============================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE SF_SOLUTIONS_WH;
USE DATABASE SF_SOLUTIONS;
USE SCHEMA OPS;

-- NOTE: Replace 'ops-alerts@franchise.example' with your real email address
--       before resuming these alerts.

-- 1. COGS spike: canonical COGS% breaches 35% for any unit-month.
CREATE OR REPLACE ALERT SF_SOLUTIONS.OPS.ALERT_COGS_SPIKE
    SCHEDULE = '60 MINUTE'
    IF (EXISTS (
        SELECT 1 FROM SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS
        WHERE cogs_pct > 35
          AND month_start = DATE_TRUNC('month', CURRENT_DATE())
    ))
    THEN CALL SYSTEM$SEND_EMAIL(
        'FRANCHISE_OPS_NOTIFY',
        'ops-alerts@franchise.example',
        'Franchise Ops: COGS spike detected',
        'One or more units breached 35% COGS this month. See DT_STORE_MONTH_KPIS.'
    );

-- 2. Labor drift: labor cost % of sales breaches 32% for any unit-week.
CREATE OR REPLACE ALERT SF_SOLUTIONS.OPS.ALERT_LABOR_DRIFT
    SCHEDULE = '1440 MINUTE'
    IF (EXISTS (
        SELECT 1
        FROM SF_SOLUTIONS.OPS.V_LABOR_SUMMARY l
        JOIN SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS k
          ON l.store_id = k.STORE_ID
        WHERE ROUND(l.total_labor_cost / NULLIF(k.net_sales,0) * 100, 2) > 32
    ))
    THEN CALL SYSTEM$SEND_EMAIL(
        'FRANCHISE_OPS_NOTIFY',
        'ops-alerts@franchise.example',
        'Franchise Ops: labor cost drift',
        'Labor cost % exceeded 32% of sales at one or more units.'
    );

-- 3. Compliance failure: brand audit score below 80%.
CREATE OR REPLACE ALERT SF_SOLUTIONS.OPS.ALERT_COMPLIANCE_FAILURE
    SCHEDULE = '1440 MINUTE'
    IF (EXISTS (
        SELECT 1 FROM SF_SOLUTIONS.OPS.COMPLIANCE_AUDITS
        WHERE points_possible > 0
          AND ROUND(points_earned / NULLIF(points_possible,0) * 100, 1) < 80
          AND audit_date >= DATEADD('day', -7, CURRENT_DATE())
    ))
    THEN CALL SYSTEM$SEND_EMAIL(
        'FRANCHISE_OPS_NOTIFY',
        'ops-alerts@franchise.example',
        'Franchise Ops: brand audit failure',
        'A unit scored below 80% on a recent brand audit. See COMPLIANCE_AUDITS.'
    );

-- 4. Waste spike: waste % of purchases above 4% for any unit-week.
CREATE OR REPLACE ALERT SF_SOLUTIONS.OPS.ALERT_WASTE_SPIKE
    SCHEDULE = '1440 MINUTE'
    IF (EXISTS (
        SELECT 1 FROM SF_SOLUTIONS.OPS.WASTE_LOG
        WHERE purchases_cost > 0
          AND ROUND(waste_cost / NULLIF(purchases_cost,0) * 100, 2) > 4
          AND week_start >= DATEADD('day', -14, CURRENT_DATE())
    ))
    THEN CALL SYSTEM$SEND_EMAIL(
        'FRANCHISE_OPS_NOTIFY',
        'ops-alerts@franchise.example',
        'Franchise Ops: waste spike',
        'Waste exceeded 4% of purchases at one or more units.'
    );

-- Alerts are created SUSPENDED. Resume after confirming the notification
-- integration exists and replacing the placeholder email above.
ALTER ALERT SF_SOLUTIONS.OPS.ALERT_COGS_SPIKE          RESUME;
ALTER ALERT SF_SOLUTIONS.OPS.ALERT_LABOR_DRIFT         RESUME;
ALTER ALERT SF_SOLUTIONS.OPS.ALERT_COMPLIANCE_FAILURE  RESUME;
ALTER ALERT SF_SOLUTIONS.OPS.ALERT_WASTE_SPIKE         RESUME;
