# SQL Patterns — Franchise Operations

Component: `cmp-sql-patterns-ref` (solution_design). Reusable, pushdown-friendly,
set-based patterns the skills reference. Grounded on `SF_SOLUTIONS.OPS` objects
and the dynamic tables in `scripts/setup.sql`.

## 1. Same-Store Sales Growth (period-over-period, comp units only)

Restrict to units open in BOTH periods so a new opening is not counted as a comp.

```sql
SELECT
    curr.STORE_ID,
    curr.BRAND,
    curr.month_start,
    curr.net_sales                                   AS net_sales_curr,
    prior.net_sales                                  AS net_sales_prior_year,
    ROUND((curr.net_sales - prior.net_sales)
          / NULLIF(prior.net_sales, 0) * 100, 2)     AS sss_growth_pct
FROM SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS curr
JOIN SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS prior          -- INNER JOIN => comp units only
     ON  curr.STORE_ID    = prior.STORE_ID
     AND prior.month_start = DATEADD('year', -1, curr.month_start)
WHERE curr.BRAND = :brand;
```

Use `INNER JOIN` for a strict comp-store base; the dynamic table
`DT_SAME_STORE_BASE` uses a `LEFT JOIN` to keep new units visible with NULL
growth (they are then filtered out, not zeroed).

## 2. Network percentile ranking

Rank across the full network (both brands) from the unified model.

```sql
SELECT
    store_code,
    brand,
    net_sales,
    PERCENT_RANK() OVER (ORDER BY net_sales)          AS network_pctile,
    NTILE(4)       OVER (ORDER BY net_sales)          AS network_quartile,
    net_sales - MEDIAN(net_sales) OVER ()             AS delta_to_network_median
FROM SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS
WHERE month_start = DATE_TRUNC('month', CURRENT_DATE());
```

To compare productivity fairly across brands (Brand A ~$11 vs Brand B ~$18 ticket),
`PARTITION BY brand` in the window, or normalize the metric first.

## 3. Prime-cost rollup (COGS + labor)

Canonical COGS% denominator = net sales; prime cost combines food + labor over sales.

```sql
SELECT
    k.STORE_ID,
    k.BRAND,
    k.month_start,
    k.cogs_pct,                                        -- canonical COGS ÷ net sales
    ROUND(l.total_labor_cost / NULLIF(k.net_sales,0) * 100, 2) AS labor_cost_pct,
    ROUND(k.cogs_pct
          + l.total_labor_cost / NULLIF(k.net_sales,0) * 100, 2) AS prime_cost_pct
FROM SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS k
LEFT JOIN (
    SELECT store_id, SUM(total_labor_cost) AS total_labor_cost
    FROM SF_SOLUTIONS.OPS.V_LABOR_SUMMARY
    GROUP BY store_id
) l ON k.STORE_ID = l.store_id
WHERE k.BRAND = :brand;
```

## Guardrails baked into every pattern

- **Always `NULLIF(denominator, 0)`** — no divide-by-zero (silent NULLs beat
  errors, but a NULL rate is surfaced by the DMFs in setup.sql).
- **Read dynamic tables / views, never the 2M-row `POS_TRANSACTIONS` directly**
  for aggregates (WAF performance_optimization).
- **Segment by `BRAND`** — pooling brands mixes incompatible ticket sizes.
- **Prefer `INNER JOIN` for comp populations**; use `LEFT JOIN` only when you
  intend to keep and then explicitly filter non-matches.
