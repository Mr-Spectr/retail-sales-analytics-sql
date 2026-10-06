# Retail Sales Analytics (PostgreSQL)

A portfolio-ready SQL mini-project covering a normalized transactional design, a star-schema reporting layer, recursive CTEs, subqueries, set operators, window functions, rollups, cubes, grouping sets, views, and a materialized view.

## Business question

How are revenue and order volume changing month over month, and which product categories and regions are driving that change?

## Project layout

| File | Purpose |
| --- | --- |
| `sql/01_schema.sql` | Normalized OLTP tables (3NF) and dimensional reporting tables |
| `sql/02_seed_data.sql` | Small, realistic sample dataset |
| `sql/03_analytics.sql` | Reusable views, materialized view, and analysis queries |
| `sql/04_exercises.sql` | Practice questions mapped to the course topics |

## Run it

Requires PostgreSQL 14+.

```bash
createdb retail_analytics
psql -d retail_analytics -f sql/01_schema.sql
psql -d retail_analytics -f sql/02_seed_data.sql
psql -d retail_analytics -f sql/03_analytics.sql
```

Refresh the reporting cache after new facts are loaded:

```sql
REFRESH MATERIALIZED VIEW reporting.mv_monthly_category_sales;
```

## Design

The `sales` schema contains normalized source entities: customers, addresses, products, orders, and order items. Customer addresses are separated to prevent repeating address attributes, and order items use a composite key to identify a line within an order.

The `reporting` schema holds a star schema optimized for analytics:

```text
dim_date      dim_customer      dim_product
     \              |                /
              fact_sales
```

`fact_sales` stores one row per order line with the historical unit price and discount captured at time of sale. This keeps prior reporting stable even if a product's current list price changes.

## Highlights

- `reporting.v_monthly_sales_mom` uses CTEs plus `LAG()` to calculate MoM change and growth percentage.
- `reporting.v_product_sales_rank` uses `DENSE_RANK()` and `NTILE()` to classify product performance.
- `03_analytics.sql` includes correlated, scalar, and `EXISTS` / `NOT EXISTS` subqueries.
- `ROLLUP`, `CUBE`, and `GROUPING SETS` answer multi-level aggregation questions in one query.
- A materialized view provides a refreshable category-by-month reporting cache.

## Example interview prompt

> Return each month's revenue, previous month's revenue, absolute change, and percentage growth. Exclude a growth percentage where the prior month has no revenue.

See the `Month-over-month revenue` section in `sql/03_analytics.sql` for the solution.
