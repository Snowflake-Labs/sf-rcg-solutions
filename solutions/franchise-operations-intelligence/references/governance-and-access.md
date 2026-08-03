# Governance & Access — Franchisee Unit Scoping

Component: `cmp-governance-access-ref` (solution_design, pillar platform_governance).
Row access policies, column masking, and RBAC so a franchisee sees only their own
units/brands and sensitive financials are protected. WAF: security_governance —
least privilege, brand/unit row scoping, PII/financial masking.

Applies to the unified view (`FRANCHISE_OPS_UNIFIED`) and its base tables. The
`franchise-analyst` agent inherits these policies because it queries only the
governed view.

## RBAC model (least privilege)

| Role | Purpose | Grants |
|---|---|---|
| `SYSADMIN` | build/own objects | owns DTs, DMFs, view; runs remediation |
| `FRANCHISE_OPS_ADMIN` | network-wide analyst | SELECT on unified view, no row filter |
| `FRANCHISE_OWNER_<id>` | one operator | SELECT on unified view, row-filtered to their units |
| `ACCOUNTADMIN` | account setup only | resource monitors (cost-governance section) — nothing routine |

Setup never uses `ACCOUNTADMIN` for data work; `ACCOUNTADMIN` is scoped to the
single resource-monitor action.

## Row access policy — owner → their units

A mapping table binds a role to the stores it may see, then a row access policy
enforces it on every query, including the agent's.

```sql
USE ROLE SYSADMIN;

CREATE TABLE IF NOT EXISTS SF_SOLUTIONS.OPS.FRANCHISEE_ROLE_MAP (
    ROLE_NAME   VARCHAR NOT NULL,
    STORE_ID    NUMBER  NOT NULL,
    BRAND       VARCHAR NOT NULL
);

CREATE OR REPLACE ROW ACCESS POLICY SF_SOLUTIONS.OPS.RAP_UNIT_SCOPE
    AS (store_id NUMBER) RETURNS BOOLEAN ->
        CURRENT_ROLE() IN ('FRANCHISE_OPS_ADMIN','SYSADMIN','ACCOUNTADMIN')
        OR EXISTS (
            SELECT 1 FROM SF_SOLUTIONS.OPS.FRANCHISEE_ROLE_MAP m
            WHERE m.ROLE_NAME = CURRENT_ROLE()
              AND m.STORE_ID  = store_id
        );

ALTER TABLE SF_SOLUTIONS.OPS.STORE_MASTER     ADD ROW ACCESS POLICY SF_SOLUTIONS.OPS.RAP_UNIT_SCOPE ON (STORE_ID);
ALTER TABLE SF_SOLUTIONS.OPS.POS_TRANSACTIONS ADD ROW ACCESS POLICY SF_SOLUTIONS.OPS.RAP_UNIT_SCOPE ON (STORE_ID);
```

## Column masking — sensitive financials & PII

```sql
-- Employee names in LABOR_WEEKLY (PII) — unmask only for privileged roles.
CREATE OR REPLACE MASKING POLICY SF_SOLUTIONS.OPS.MASK_EMPLOYEE_NAME
    AS (val VARCHAR) RETURNS VARCHAR ->
        CASE WHEN CURRENT_ROLE() IN ('FRANCHISE_OPS_ADMIN','SYSADMIN')
             THEN val ELSE '***MASKED***' END;

ALTER TABLE SF_SOLUTIONS.OPS.LABOR_WEEKLY
    MODIFY COLUMN employee_name SET MASKING POLICY SF_SOLUTIONS.OPS.MASK_EMPLOYEE_NAME;

-- Investment/equity figures — owners see their own only (row policy already
-- scopes rows); mask for any non-privileged cross-unit read.
CREATE OR REPLACE MASKING POLICY SF_SOLUTIONS.OPS.MASK_INVESTMENT
    AS (val NUMBER) RETURNS NUMBER ->
        CASE WHEN CURRENT_ROLE() IN ('FRANCHISE_OPS_ADMIN','SYSADMIN')
                  OR CURRENT_ROLE() LIKE 'FRANCHISE_OWNER_%'
             THEN val ELSE NULL END;

ALTER TABLE SF_SOLUTIONS.OPS.UNIT_INVESTMENT
    MODIFY COLUMN equity_invested SET MASKING POLICY SF_SOLUTIONS.OPS.MASK_INVESTMENT;
```

## Advisory

- Masking is not yet tied to a data-classification source. Follow-up: classify/tag
  PII columns (`SYSTEM$CLASSIFY`) and drive masking from tags.
- Agent row-policy inheritance should be verified with a test that queries the
  unified view as `FRANCHISE_OWNER_<id>` and confirms only that owner's rows return.

## Agent inheritance

The `franchise-analyst` agent runs under the caller's role and queries only
`FRANCHISE_OPS_UNIFIED`, so `RAP_UNIT_SCOPE` and the masking policies apply to
every agent answer automatically — no separate agent-side filtering needed.
