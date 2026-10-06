-- Retail Sales Analytics: PostgreSQL 14+
-- Source layer is normalized (3NF); reporting layer is a dimensional star schema.

DROP SCHEMA IF EXISTS reporting CASCADE;
DROP SCHEMA IF EXISTS sales CASCADE;
CREATE SCHEMA sales;
CREATE SCHEMA reporting;

CREATE TABLE sales.customer (
    customer_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name      TEXT NOT NULL,
    last_name       TEXT NOT NULL,
    email           TEXT NOT NULL UNIQUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sales.customer_address (
    address_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id     INTEGER NOT NULL REFERENCES sales.customer(customer_id),
    address_type    TEXT NOT NULL CHECK (address_type IN ('billing', 'shipping')),
    city            TEXT NOT NULL,
    state_code      CHAR(2) NOT NULL,
    country_code    CHAR(2) NOT NULL DEFAULT 'IN',
    UNIQUE (customer_id, address_type)
);

CREATE TABLE sales.product_category (
    category_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name   TEXT NOT NULL UNIQUE
);

CREATE TABLE sales.product (
    product_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id     INTEGER NOT NULL REFERENCES sales.product_category(category_id),
    product_name    TEXT NOT NULL UNIQUE,
    list_price      NUMERIC(12,2) NOT NULL CHECK (list_price >= 0),
    active          BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE sales.sales_order (
    order_id        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id     INTEGER NOT NULL REFERENCES sales.customer(customer_id),
    order_date      DATE NOT NULL,
    status          TEXT NOT NULL CHECK (status IN ('completed', 'cancelled', 'refunded')),
    shipping_city   TEXT NOT NULL,
    shipping_state  CHAR(2) NOT NULL
);

CREATE TABLE sales.sales_order_item (
    order_id        INTEGER NOT NULL REFERENCES sales.sales_order(order_id),
    line_number     SMALLINT NOT NULL CHECK (line_number > 0),
    product_id      INTEGER NOT NULL REFERENCES sales.product(product_id),
    quantity        INTEGER NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
    discount_pct    NUMERIC(5,4) NOT NULL DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 1),
    PRIMARY KEY (order_id, line_number)
);

CREATE INDEX ix_order_completed_date ON sales.sales_order (order_date) WHERE status = 'completed';
CREATE INDEX ix_order_item_product ON sales.sales_order_item (product_id);

CREATE TABLE reporting.dim_date (
    date_key        INTEGER PRIMARY KEY,
    full_date       DATE NOT NULL UNIQUE,
    month_start     DATE NOT NULL,
    calendar_year   SMALLINT NOT NULL,
    calendar_month  SMALLINT NOT NULL CHECK (calendar_month BETWEEN 1 AND 12),
    month_name      TEXT NOT NULL,
    quarter_number  SMALLINT NOT NULL CHECK (quarter_number BETWEEN 1 AND 4)
);

CREATE TABLE reporting.dim_customer (
    customer_key    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id     INTEGER NOT NULL UNIQUE REFERENCES sales.customer(customer_id),
    customer_name   TEXT NOT NULL,
    home_state      CHAR(2) NOT NULL
);

CREATE TABLE reporting.dim_product (
    product_key     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id      INTEGER NOT NULL UNIQUE REFERENCES sales.product(product_id),
    product_name    TEXT NOT NULL,
    category_name   TEXT NOT NULL
);

CREATE TABLE reporting.fact_sales (
    sales_key       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id        INTEGER NOT NULL REFERENCES sales.sales_order(order_id),
    line_number     SMALLINT NOT NULL,
    date_key        INTEGER NOT NULL REFERENCES reporting.dim_date(date_key),
    customer_key    INTEGER NOT NULL REFERENCES reporting.dim_customer(customer_key),
    product_key     INTEGER NOT NULL REFERENCES reporting.dim_product(product_key),
    shipping_state  CHAR(2) NOT NULL,
    quantity        INTEGER NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(12,2) NOT NULL,
    discount_pct    NUMERIC(5,4) NOT NULL,
    net_sales       NUMERIC(14,2) NOT NULL,
    UNIQUE (order_id, line_number)
);

CREATE INDEX ix_fact_sales_date ON reporting.fact_sales (date_key);
CREATE INDEX ix_fact_sales_product ON reporting.fact_sales (product_key);
