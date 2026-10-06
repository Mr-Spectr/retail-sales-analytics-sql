-- Repeatable sample data spanning four months and three regions.

INSERT INTO sales.product_category (category_name) VALUES
    ('Electronics'), ('Home Office'), ('Accessories');

INSERT INTO sales.product (category_id, product_name, list_price) VALUES
    (1, 'Wireless Headphones', 2500.00),
    (1, 'Mechanical Keyboard', 4200.00),
    (2, 'Ergonomic Chair', 12000.00),
    (2, 'LED Desk Lamp', 1800.00),
    (3, 'Laptop Sleeve', 950.00),
    (3, 'USB-C Hub', 2200.00);

INSERT INTO sales.customer (first_name, last_name, email) VALUES
    ('Aarav', 'Sharma', 'aarav@example.com'),
    ('Diya', 'Patel', 'diya@example.com'),
    ('Kabir', 'Singh', 'kabir@example.com'),
    ('Meera', 'Nair', 'meera@example.com'),
    ('Rohan', 'Gupta', 'rohan@example.com');

INSERT INTO sales.customer_address (customer_id, address_type, city, state_code) VALUES
    (1, 'billing', 'Mumbai', 'MH'), (1, 'shipping', 'Mumbai', 'MH'),
    (2, 'billing', 'Ahmedabad', 'GJ'), (2, 'shipping', 'Ahmedabad', 'GJ'),
    (3, 'billing', 'Delhi', 'DL'), (3, 'shipping', 'Delhi', 'DL'),
    (4, 'billing', 'Kochi', 'KL'), (4, 'shipping', 'Kochi', 'KL'),
    (5, 'billing', 'Pune', 'MH'), (5, 'shipping', 'Pune', 'MH');

INSERT INTO sales.sales_order (customer_id, order_date, status, shipping_city, shipping_state) VALUES
    (1, '2026-01-05', 'completed', 'Mumbai', 'MH'),
    (2, '2026-01-18', 'completed', 'Ahmedabad', 'GJ'),
    (3, '2026-02-03', 'completed', 'Delhi', 'DL'),
    (1, '2026-02-16', 'completed', 'Mumbai', 'MH'),
    (4, '2026-02-28', 'completed', 'Kochi', 'KL'),
    (5, '2026-03-06', 'completed', 'Pune', 'MH'),
    (2, '2026-03-11', 'completed', 'Ahmedabad', 'GJ'),
    (3, '2026-03-20', 'completed', 'Delhi', 'DL'),
    (4, '2026-04-04', 'completed', 'Kochi', 'KL'),
    (1, '2026-04-15', 'completed', 'Mumbai', 'MH'),
    (5, '2026-04-19', 'cancelled', 'Pune', 'MH');

INSERT INTO sales.sales_order_item (order_id, line_number, product_id, quantity, unit_price, discount_pct) VALUES
    (1, 1, 1, 1, 2500.00, 0.00), (1, 2, 5, 1, 950.00, 0.00),
    (2, 1, 4, 2, 1800.00, 0.10),
    (3, 1, 2, 1, 4200.00, 0.00), (3, 2, 6, 1, 2200.00, 0.05),
    (4, 1, 3, 1, 12000.00, 0.15),
    (5, 1, 5, 2, 950.00, 0.00), (5, 2, 4, 1, 1800.00, 0.00),
    (6, 1, 1, 2, 2500.00, 0.10),
    (7, 1, 6, 2, 2200.00, 0.00),
    (8, 1, 2, 1, 4200.00, 0.05), (8, 2, 5, 1, 950.00, 0.00),
    (9, 1, 3, 1, 12000.00, 0.20),
    (10, 1, 4, 3, 1800.00, 0.00),
    (11, 1, 1, 1, 2500.00, 0.00);

INSERT INTO reporting.dim_date (date_key, full_date, month_start, calendar_year, calendar_month, month_name, quarter_number)
SELECT TO_CHAR(day::date, 'YYYYMMDD')::INTEGER,
       day::date,
       DATE_TRUNC('month', day)::date,
       EXTRACT(YEAR FROM day)::SMALLINT,
       EXTRACT(MONTH FROM day)::SMALLINT,
       TO_CHAR(day, 'FMMonth'),
       EXTRACT(QUARTER FROM day)::SMALLINT
FROM GENERATE_SERIES('2026-01-01'::date, '2026-04-30'::date, '1 day') AS gs(day);

INSERT INTO reporting.dim_customer (customer_id, customer_name, home_state)
SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name), a.state_code
FROM sales.customer c
JOIN sales.customer_address a ON a.customer_id = c.customer_id AND a.address_type = 'billing';

INSERT INTO reporting.dim_product (product_id, product_name, category_name)
SELECT p.product_id, p.product_name, pc.category_name
FROM sales.product p JOIN sales.product_category pc ON pc.category_id = p.category_id;

INSERT INTO reporting.fact_sales
    (order_id, line_number, date_key, customer_key, product_key, shipping_state, quantity, unit_price, discount_pct, net_sales)
SELECT o.order_id, oi.line_number, TO_CHAR(o.order_date, 'YYYYMMDD')::INTEGER,
       dc.customer_key, dp.product_key, o.shipping_state,
       oi.quantity, oi.unit_price, oi.discount_pct,
       ROUND(oi.quantity * oi.unit_price * (1 - oi.discount_pct), 2)
FROM sales.sales_order o
JOIN sales.sales_order_item oi ON oi.order_id = o.order_id
JOIN reporting.dim_customer dc ON dc.customer_id = o.customer_id
JOIN reporting.dim_product dp ON dp.product_id = oi.product_id
WHERE o.status = 'completed';
