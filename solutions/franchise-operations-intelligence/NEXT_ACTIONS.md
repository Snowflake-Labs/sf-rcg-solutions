---
description: >
  Show next actions after installing Franchise Multi-Unit Operations Intelligence.
  Triggers: what next, next steps, what can I do, how to use this.
---

# Next Actions: Franchise Multi-Unit Operations Intelligence

## Phase 1: Quick Exploration

1. **Access the solution objects**
   - Snowsight: Data > Databases > SF_SOLUTIONS > OPS
   - Browse `DT_STORE_MONTH_KPIS`, `DT_SAME_STORE_BASE`, `FRANCHISE_OPS_UNIFIED`

2. **Try core queries**

   Brand-segmented net sales and COGS% for the current month:
   ```sql
   SELECT * FROM SEMANTIC_VIEW(
     SF_SOLUTIONS.OPS.FRANCHISE_OPS_UNIFIED
     DIMENSIONS stores.brand, txns.transaction_date
     METRICS txns.net_sales, txns.cogs_pct, txns.gross_margin_pct
   );
   ```

   Top 10 units by COGS% this month:
   ```sql
   SELECT store_id, brand, month_start, cogs_pct
   FROM SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS
   WHERE month_start = DATE_TRUNC('month', CURRENT_DATE())
   ORDER BY cogs_pct DESC
   LIMIT 10;
   ```

   Same-store sales growth by brand:
   ```sql
   SELECT brand, AVG(sss_growth_pct) AS avg_sss_growth
   FROM SF_SOLUTIONS.OPS.DT_SAME_STORE_BASE
   WHERE month_start = DATE_TRUNC('month', DATEADD('month', -1, CURRENT_DATE()))
   GROUP BY brand
   ORDER BY brand;
   ```

   Check DMF data quality results:
   ```sql
   SELECT * FROM TABLE(INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
     REF_ENTITY_NAME => 'SF_SOLUTIONS.OPS.POS_TRANSACTIONS',
     REF_ENTITY_DOMAIN => 'TABLE'));
   ```

## Phase 2: Use the Skills

| Skill | Use it for |
|-------|-----------|
| `primary-workflow` | Router — start here for any franchise question |
| `kpi-definitions` | Canonical definition + grounding status for all 25 KPIs |
| `domain-glossary` | Cross-brand vocabulary reconciliation (QSR/Brand A/Brand B) |
| `unit-performance-monitoring` | Net sales, gross margin, transactions, SSS, store profit |
| `network-benchmarking` | Percentile rank, sales/sqft, sales/labor-hr, CSAT |
| `labor-optimization` | Labor cost %, sales/labor-hr, overtime, turnover |
| `cogs-waste-control` | Canonical COGS%, variance, waste, shrinkage |
| `compliance-tracking` | Brand audit, violations, corrective actions, checklists |
| `expansion-evaluation` | Unit ROI, payback, site projection, cash-on-cash |

## Phase 3: Enable Alerts

1. Create the notification integration (see `references/operational-runbook.md`):
   ```sql
   CREATE NOTIFICATION INTEGRATION IF NOT EXISTS FRANCHISE_OPS_NOTIFY
     TYPE = EMAIL
     ENABLED = TRUE;
   ```
2. Replace `ops-alerts@franchise.example` in `scripts/setup.sql` with your actual address
3. Re-run the alerts section or resume them manually:
   ```sql
   ALTER ALERT SF_SOLUTIONS.OPS.ALERT_COGS_SPIKE RESUME;
   ALTER ALERT SF_SOLUTIONS.OPS.ALERT_LABOR_DRIFT RESUME;
   ALTER ALERT SF_SOLUTIONS.OPS.ALERT_COMPLIANCE_FAILURE RESUME;
   ALTER ALERT SF_SOLUTIONS.OPS.ALERT_WASTE_SPIKE RESUME;
   ```

## Phase 4: Connect Real Data

1. Load your real POS transaction data into `SF_SOLUTIONS.OPS.POS_TRANSACTIONS`
2. Load franchisee and store master data
3. For ungrounded KPIs (labor, waste, compliance, expansion), follow the ingestion
   contracts in `references/missing-data-schemas.md`
4. Update the `BRAND` backfill in setup.sql if your store codes use a different convention

## Phase 5: Production Deployment

1. Set up row access policies so each franchisee sees only their own units
   (see `references/governance-and-access.md`)
2. Apply column masking policies on sensitive franchisee financial data
3. Adjust Dynamic Table `TARGET_LAG` to match your data freshness requirements
4. Review the `RM_FRANCHISE_OPS` resource monitor credit quota for your expected workload
