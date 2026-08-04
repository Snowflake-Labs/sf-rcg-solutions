USE ROLE ACCOUNTADMIN;

-- Drop solution schemas (preserves shared SF_SOLUTIONS database and warehouse)
DROP SCHEMA IF EXISTS SF_SOLUTIONS.OPS CASCADE;

-- Drop solution-scoped resource monitor
DROP RESOURCE MONITOR IF EXISTS RM_FRANCHISE_OPS;
