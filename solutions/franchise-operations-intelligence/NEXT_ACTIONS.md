---
description: >
  Show next actions after installing Franchise Multi-Unit Operations Intelligence.
  Triggers: what next, next steps, what can I do, how to use this.
---

# Next Actions: Franchise Multi-Unit Operations Intelligence

## Quick Exploration

1. **Access the solution objects**
   - Snowsight: Data > Databases > SF_SOLUTIONS > OPS
   - Browse `DT_STORE_MONTH_KPIS`, `DT_SAME_STORE_BASE`, `FRANCHISE_OPS_UNIFIED`

2. **Try core queries**

   Brand-segmented net sales and canonical COGS%:
   ```sql
   SELECT * FROM SEMANTIC_VIEW(
     SF_SOLUTIONS.OPS.FRANCHISE_OPS_UNIFIED
     DIMENSIONS stores.brand
     METRICS txns.net_sales, txns.cogs_pct, txns.gross_margin_pct
   );
   ```

   Top 10 units by COGS% this month:
   ```sql
   SELECT store_id, brand, month_start, cogs_pct
   FROM SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS
   WHERE month_start = DATE_TRUNC('month', CURRENT_DATE())
   ORDER BY cogs_pct DESC LIMIT 10;
   ```

   Same-store sales growth by brand (prior month):
   ```sql
   SELECT brand, AVG(sss_growth_pct) AS avg_sss_growth
   FROM SF_SOLUTIONS.OPS.DT_SAME_STORE_BASE
   WHERE month_start = DATE_TRUNC('month', DATEADD('month', -1, CURRENT_DATE()))
   GROUP BY brand ORDER BY brand;
   ```

## Enable Alerts

1. Create the notification integration:
   ```sql
   CREATE NOTIFICATION INTEGRATION IF NOT EXISTS FRANCHISE_OPS_NOTIFY
     TYPE = EMAIL ENABLED = TRUE;
   ```
2. Replace `ops-alerts@franchise.example` in `scripts/setup.sql` with your address
3. Resume alerts:
   ```sql
   ALTER ALERT SF_SOLUTIONS.OPS.ALERT_COGS_SPIKE RESUME;
   ALTER ALERT SF_SOLUTIONS.OPS.ALERT_LABOR_DRIFT RESUME;
   ALTER ALERT SF_SOLUTIONS.OPS.ALERT_COMPLIANCE_FAILURE RESUME;
   ALTER ALERT SF_SOLUTIONS.OPS.ALERT_WASTE_SPIKE RESUME;
   ```

## Use the Skills

| Skill | Use it for |
|-------|-----------|
| `primary-workflow` | Router — start here for any franchise question |
| `kpi-definitions` | Canonical definition + grounding status for all 25 KPIs |
| `domain-glossary` | Cross-brand vocabulary reconciliation |
| `unit-performance-monitoring` | Net sales, gross margin, transactions, SSS |
| `network-benchmarking` | Percentile rank, sales/sqft, sales/labor-hr, CSAT |
| `labor-optimization` | Labor cost %, sales/labor-hr, overtime, turnover |
| `cogs-waste-control` | Canonical COGS%, variance, waste, shrinkage |
| `compliance-tracking` | Brand audit, violations, corrective actions |
| `expansion-evaluation` | Unit ROI, payback, site projection, cash-on-cash |

## Connect Real Data

1. Load POS transaction data into `SF_SOLUTIONS.OPS.POS_TRANSACTIONS`
2. Load franchisee and store master data
3. For ungrounded KPIs (labor, waste, compliance, expansion), follow ingestion
   contracts in `references/missing-data-schemas.md`

## Production Deployment

1. Apply row access policies so each franchisee sees only their own units
   (`references/governance-and-access.md`)
2. Apply column masking on sensitive financial/PII columns
3. Adjust Dynamic Table `TARGET_LAG` to match your freshness requirements
4. Review the `RM_FRANCHISE_OPS` resource monitor credit quota
