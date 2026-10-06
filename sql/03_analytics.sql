-- Reporting objects and answer-ready analysis queries.

CREATE OR REPLACE VIEW reporting.v_monthly_sales AS
SELECT d.month_start,
       SUM(f.net_sales) AS revenue,
       COUNT(DISTINCT f.order_id) AS orders,
       SUM(f.quantity) AS units_sold
FROM reporting.fact_sales f
JOIN reporting.dim_date d ON d.date_key = f.date_key
GROUP BY d.month_start;

CREATE OR REPLACE VIEW reporting.v_monthly_sales_mom AS
WITH monthly AS (
    SELECT month_start, revenue, orders, units_sold
    FROM reporting.v_monthly_sales
), with_prior AS (
    SELECT *, LAG(revenue) OVER (ORDER BY month_start) AS previous_month_revenue
    FROM monthly
)
SELECT month_start, revenue, orders, units_sold, previous_month_revenue,
       revenue - previous_month_revenue AS revenue_change,
       ROUND(100 * (revenue - previous_month_revenue) / NULLIF(previous_month_revenue, 0), 2) AS mom_growth_pct
FROM with_prior;

CREATE OR REPLACE VIEW reporting.v_product_sales_rank AS
WITH product_totals AS (
    SELECT p.category_name, p.product_name, SUM(f.net_sales) AS revenue
    FROM reporting.fact_sales f JOIN reporting.dim_product p ON p.product_key = f.product_key
    GROUP BY p.category_name, p.product_name
)
SELECT *,
       DENSE_RANK() OVER (PARTITION BY category_name ORDER BY revenue DESC) AS category_revenue_rank,
       NTILE(4) OVER (ORDER BY revenue DESC) AS revenue_quartile
FROM product_totals;

CREATE MATERIALIZED VIEW reporting.mv_monthly_category_sales AS
SELECT d.month_start, p.category_name,
       SUM(f.net_sales) AS revenue,
       SUM(f.quantity) AS units_sold
FROM reporting.fact_sales f
JOIN reporting.dim_date d ON d.date_key = f.date_key
JOIN reporting.dim_product p ON p.product_key = f.product_key
GROUP BY d.month_start, p.category_name;
CREATE UNIQUE INDEX ux_mv_monthly_category_sales ON reporting.mv_monthly_category_sales (month_start, category_name);

-- 1. Window report: MoM revenue with a running total and prior period value.
SELECT month_start, revenue, previous_month_revenue, revenue_change, mom_growth_pct,
       SUM(revenue) OVER (ORDER BY month_start ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_revenue
FROM reporting.v_monthly_sales_mom
ORDER BY month_start;

-- 2. LAG and LEAD: compare each category month to its own adjacent months.
SELECT month_start, category_name, revenue,
       LAG(revenue) OVER (PARTITION BY category_name ORDER BY month_start) AS prior_month_revenue,
       LEAD(revenue) OVER (PARTITION BY category_name ORDER BY month_start) AS next_month_revenue
FROM reporting.mv_monthly_category_sales
ORDER BY category_name, month_start;

-- 3. ROLLUP: region subtotals and grand total. GROUPING distinguishes total rows.
SELECT CASE WHEN GROUPING(shipping_state) = 1 THEN 'ALL REGIONS' ELSE shipping_state END AS region,
       SUM(net_sales) AS revenue
FROM reporting.fact_sales
GROUP BY ROLLUP (shipping_state)
ORDER BY GROUPING(shipping_state), shipping_state;

-- 4. CUBE: every state/category combination plus both dimensions' subtotals.
SELECT shipping_state, category_name, SUM(net_sales) AS revenue
FROM reporting.fact_sales f JOIN reporting.dim_product p ON p.product_key = f.product_key
GROUP BY CUBE (shipping_state, category_name)
ORDER BY shipping_state NULLS LAST, category_name NULLS LAST;

-- 5. GROUPING SETS: deliberately request just category, state, and overall totals.
SELECT shipping_state, p.category_name, SUM(f.net_sales) AS revenue
FROM reporting.fact_sales f JOIN reporting.dim_product p ON p.product_key = f.product_key
GROUP BY GROUPING SETS ((shipping_state), (p.category_name), ());

-- 6. Scalar subquery: products priced above the current average list price.
SELECT product_name, list_price
FROM sales.product
WHERE list_price > (SELECT AVG(list_price) FROM sales.product)
ORDER BY list_price DESC;

-- 7. Correlated subquery: customers whose completed-order revenue is above the average customer revenue.
SELECT dc.customer_name, SUM(f.net_sales) AS customer_revenue
FROM reporting.fact_sales f JOIN reporting.dim_customer dc ON dc.customer_key = f.customer_key
GROUP BY dc.customer_key, dc.customer_name
HAVING SUM(f.net_sales) > (
    SELECT AVG(customer_revenue)
    FROM (
        SELECT SUM(net_sales) AS customer_revenue
        FROM reporting.fact_sales
        GROUP BY customer_key
    ) customer_totals
);

-- 8. EXISTS / NOT EXISTS: active products sold at least once, and never sold.
SELECT p.product_name
FROM sales.product p
WHERE p.active
  AND EXISTS (SELECT 1 FROM sales.sales_order_item oi WHERE oi.product_id = p.product_id);

SELECT p.product_name
FROM sales.product p
WHERE NOT EXISTS (SELECT 1 FROM sales.sales_order_item oi WHERE oi.product_id = p.product_id);

-- 9. Set operators: completed-order customers in MH or GJ; INTERSECT finds repeat buyers.
(SELECT customer_id FROM sales.sales_order WHERE shipping_state = 'MH' AND status = 'completed')
UNION
(SELECT customer_id FROM sales.sales_order WHERE shipping_state = 'GJ' AND status = 'completed');

(SELECT customer_id FROM sales.sales_order WHERE order_date < DATE '2026-03-01' AND status = 'completed')
INTERSECT
(SELECT customer_id FROM sales.sales_order WHERE order_date >= DATE '2026-03-01' AND status = 'completed');

-- 10. Recursive CTE: generate month starts, including months with no sales.
WITH RECURSIVE months AS (
    SELECT DATE '2026-01-01' AS month_start
    UNION ALL
    SELECT (month_start + INTERVAL '1 month')::date FROM months WHERE month_start < DATE '2026-04-01'
)
SELECT m.month_start, COALESCE(v.revenue, 0) AS revenue
FROM months m LEFT JOIN reporting.v_monthly_sales v USING (month_start)
ORDER BY m.month_start;
