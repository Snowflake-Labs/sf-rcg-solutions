# SQL Patterns — Franchise Operations

Reusable, pushdown-friendly patterns grounded on `SF_SOLUTIONS.OPS`.

## 1. Same-Store Sales Growth (comp units only)

```sql
SELECT
    curr.STORE_ID, curr.BRAND, curr.month_start,
    curr.net_sales                                   AS net_sales_curr,
    prior.net_sales                                  AS net_sales_prior_year,
    ROUND((curr.net_sales - prior.net_sales)
          / NULLIF(prior.net_sales, 0) * 100, 2)     AS sss_growth_pct
FROM SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS curr
JOIN SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS prior    -- INNER JOIN = comp units only
     ON  curr.STORE_ID    = prior.STORE_ID
     AND prior.month_start = DATEADD('year', -1, curr.month_start)
WHERE curr.BRAND = :brand;
```

## 2. Network percentile ranking

```sql
SELECT
    store_code, brand, net_sales,
    PERCENT_RANK() OVER (ORDER BY net_sales) AS network_pctile,
    NTILE(4)       OVER (ORDER BY net_sales) AS network_quartile,
    net_sales - MEDIAN(net_sales) OVER ()    AS delta_to_median
FROM SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS
WHERE month_start = DATE_TRUNC('month', CURRENT_DATE());
```

`PARTITION BY brand` when comparing productivity across brands.

## 3. Prime-cost rollup (COGS + labor)

```sql
SELECT
    k.STORE_ID, k.BRAND, k.month_start,
    k.cogs_pct,
    ROUND(l.total_labor_cost / NULLIF(k.net_sales,0) * 100, 2) AS labor_cost_pct,
    ROUND(k.cogs_pct + l.total_labor_cost / NULLIF(k.net_sales,0) * 100, 2) AS prime_cost_pct
FROM SF_SOLUTIONS.OPS.DT_STORE_MONTH_KPIS k
LEFT JOIN (
    SELECT store_id, SUM(total_labor_cost) AS total_labor_cost
    FROM SF_SOLUTIONS.OPS.V_LABOR_SUMMARY GROUP BY store_id
) l ON k.STORE_ID = l.store_id
WHERE k.BRAND = :brand;
```

## Guardrails

- Always `NULLIF(denominator, 0)` — no divide-by-zero.
- Read dynamic tables / views — never `POS_TRANSACTIONS` directly for aggregates.
- Segment by `BRAND` — pooling mixes incompatible ticket sizes.
- `INNER JOIN` for comp populations; `LEFT JOIN` only when you intend to keep
  and then explicitly filter non-matches.
