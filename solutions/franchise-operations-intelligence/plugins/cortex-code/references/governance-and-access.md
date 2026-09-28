# Governance & Access — Franchisee Unit Scoping

Row access policies, column masking, and RBAC so a franchisee sees only their
own units. The `franchise-analyst` agent inherits these policies automatically.

## RBAC model

| Role | Purpose |
|---|---|
| `SYSADMIN` | build/own objects; runs remediation |
| `FRANCHISE_OPS_ADMIN` | network-wide analyst, no row filter |
| `FRANCHISE_OWNER_<id>` | one operator, row-filtered to their units |
| `ACCOUNTADMIN` | resource monitors only — nothing routine |

## Row access policy

```sql
USE ROLE SYSADMIN;

CREATE TABLE IF NOT EXISTS SF_SOLUTIONS.OPS.FRANCHISEE_ROLE_MAP (
    ROLE_NAME VARCHAR NOT NULL, STORE_ID NUMBER NOT NULL, BRAND VARCHAR NOT NULL
);

CREATE OR REPLACE ROW ACCESS POLICY SF_SOLUTIONS.OPS.RAP_UNIT_SCOPE
    AS (store_id NUMBER) RETURNS BOOLEAN ->
        CURRENT_ROLE() IN ('FRANCHISE_OPS_ADMIN','SYSADMIN','ACCOUNTADMIN')
        OR EXISTS (
            SELECT 1 FROM SF_SOLUTIONS.OPS.FRANCHISEE_ROLE_MAP m
            WHERE m.ROLE_NAME = CURRENT_ROLE() AND m.STORE_ID = store_id
        );

ALTER TABLE SF_SOLUTIONS.OPS.STORE_MASTER     ADD ROW ACCESS POLICY SF_SOLUTIONS.OPS.RAP_UNIT_SCOPE ON (STORE_ID);
ALTER TABLE SF_SOLUTIONS.OPS.POS_TRANSACTIONS ADD ROW ACCESS POLICY SF_SOLUTIONS.OPS.RAP_UNIT_SCOPE ON (STORE_ID);
```

## Column masking

```sql
-- Employee names (PII)
CREATE OR REPLACE MASKING POLICY SF_SOLUTIONS.OPS.MASK_EMPLOYEE_NAME
    AS (val VARCHAR) RETURNS VARCHAR ->
        CASE WHEN CURRENT_ROLE() IN ('FRANCHISE_OPS_ADMIN','SYSADMIN')
             THEN val ELSE '***MASKED***' END;

ALTER TABLE SF_SOLUTIONS.OPS.LABOR_WEEKLY
    MODIFY COLUMN employee_name SET MASKING POLICY SF_SOLUTIONS.OPS.MASK_EMPLOYEE_NAME;

-- Investment/equity figures
CREATE OR REPLACE MASKING POLICY SF_SOLUTIONS.OPS.MASK_INVESTMENT
    AS (val NUMBER) RETURNS NUMBER ->
        CASE WHEN CURRENT_ROLE() IN ('FRANCHISE_OPS_ADMIN','SYSADMIN')
                  OR CURRENT_ROLE() LIKE 'FRANCHISE_OWNER_%'
             THEN val ELSE NULL END;

ALTER TABLE SF_SOLUTIONS.OPS.UNIT_INVESTMENT
    MODIFY COLUMN equity_invested SET MASKING POLICY SF_SOLUTIONS.OPS.MASK_INVESTMENT;
```

## Advisory

- Follow-up: classify/tag PII columns (`SYSTEM$CLASSIFY`) and drive masking from tags.
- Verify agent row-policy inheritance with a test querying as `FRANCHISE_OWNER_<id>`.
