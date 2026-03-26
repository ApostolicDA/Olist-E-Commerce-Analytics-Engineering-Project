-- =========================================
-- 1. CLEAN CATEGORY DIMENSION
-- =========================================

ALTER TABLE category
ADD COLUMN IF NOT EXISTS clean_category VARCHAR(30);

UPDATE category
SET clean_category = CASE 
    WHEN product_category_name_english IN (
        'fashion_childrens_clothes','fashion_shoes','fashion_sport',
        'fashion_underwear_beach','fashion_male_clothing',
        'fashion_female_clothing','fashion_bags_accessories'
    ) THEN 'Fashion'

    WHEN product_category_name_english IN (
        'books_technical','books_general_interest','books_imported'
    ) THEN 'Books'

    WHEN product_category_name_english IN (
        'electronics','computers_accessories','audio','telephony',
        'fixed_telephony','tablets_printing_image','consoles_games',
        'cine_photo','air_conditioning'
    ) THEN 'Electronics'

    WHEN product_category_name_english IN (
        'furniture','bed_bath_table','home_comfort',
        'home_appliances','small_appliances','housewares'
    ) THEN 'Home & Living'

    WHEN product_category_name_english IN (
        'baby','diapers_and_hygiene','toys'
    ) THEN 'Kids & Baby'

    WHEN product_category_name_english IN (
        'health_beauty','perfumery'
    ) THEN 'Beauty & Health'

    WHEN product_category_name_english = 'sports_leisure'
    THEN 'Sports & Leisure'

    WHEN product_category_name_english IN (
        'food_drink','la_cuisine'
    ) THEN 'Food & Kitchen'

    WHEN product_category_name_english IN (
        'construction_tools','garden_tools'
    ) THEN 'Tools & Garden'

    WHEN product_category_name_english = 'pet_shop'
    THEN 'Pet Supplies'

    ELSE 'General & Misc'
END;


-- =========================================
-- 2. CLEAN GEOLOCATION
-- =========================================

DROP TABLE IF EXISTS geo_clean;

CREATE TABLE geo_clean AS
SELECT
    LPAD(geolocation_zip_code_prefix::text, 5, '0') AS zip_prefix,
    AVG(geolocation_lat) AS latitude,
    AVG(geolocation_lng) AS longitude,
    MAX(geolocation_city) AS city,
    MAX(geolocation_state) AS state
FROM geolocation
GROUP BY geolocation_zip_code_prefix;


-- =========================================
-- 3. MASTER FACT TABLE
-- GRAIN: 1 ROW = 1 ORDER ITEM
-- =========================================

DROP TABLE IF EXISTS master_olist;

CREATE TABLE master_olist AS

WITH payment_agg AS (
    SELECT 
        order_id,
        SUM(payment_value) AS order_payment_value,
        COUNT(*) AS payment_count,
        MAX(payment_type) AS payment_type
    FROM order_payment
    GROUP BY order_id
),

review_agg AS (
    SELECT
        order_id,
        AVG(review_score) AS review_score
    FROM reviews
    GROUP BY order_id
)

SELECT
    -- ORDER
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    -- CUSTOMER
    c.customer_state AS cust_state,
    c.customer_city AS cust_city,
    geo_cust.latitude AS customer_lat,
    geo_cust.longitude AS customer_lng,

    -- ITEM
    i.order_item_id,
    i.product_id,
    i.seller_id,
    i.price AS item_price,
    i.freight_value AS freight_cost,

    -- PRODUCT
    p.product_name_length,
    p.product_photos_qty,
    cat.clean_category,

    -- PAYMENT
    pay.order_payment_value,
    pay.payment_type,

    -- REVIEW
    rev.review_score,

    -- DELIVERY
    (o.order_delivered_customer_date - o.order_purchase_timestamp) AS delivery_days,
    (o.order_delivered_customer_date - o.order_estimated_delivery_date) AS delay_days

FROM orders o
JOIN order_items i ON o.order_id = i.order_id
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN geo_clean geo_cust 
    ON LPAD(c.customer_zip_code_prefix::text, 5, '0') = geo_cust.zip_prefix
JOIN products p ON i.product_id = p.product_id
LEFT JOIN category cat ON p.product_category_name = cat.product_category_name
LEFT JOIN payment_agg pay ON o.order_id = pay.order_id
LEFT JOIN review_agg rev ON o.order_id = rev.order_id;


-- =========================================
-- 4. FEATURE ENGINEERING
-- =========================================

ALTER TABLE master_olist ADD COLUMN name_length_bucket TEXT;
ALTER TABLE master_olist ADD COLUMN photos_qty_bucket TEXT;

UPDATE master_olist
SET name_length_bucket = CASE
    WHEN product_name_length IS NULL THEN 'Unknown'
    WHEN product_name_length BETWEEN 0 AND 10 THEN 'Very Short (0-10)'
    WHEN product_name_length BETWEEN 11 AND 20 THEN 'Short (11-20)'
    WHEN product_name_length BETWEEN 21 AND 40 THEN 'Medium (21-40)'
    WHEN product_name_length BETWEEN 41 AND 55 THEN 'Long (41-55)'
    ELSE 'Very Long (56+)'
END;

UPDATE master_olist
SET photos_qty_bucket = CASE
    WHEN product_photos_qty IS NULL THEN 'Unknown'
    WHEN product_photos_qty = 0 THEN 'No Photos'
    WHEN product_photos_qty = 1 THEN '1 Photo'
    WHEN product_photos_qty BETWEEN 2 AND 3 THEN '2-3 Photos'
    WHEN product_photos_qty BETWEEN 4 AND 6 THEN '4-6 Photos'
    ELSE '7+ Photos'
END;


-- =========================================
-- 5. POWER BI VIEW (FINAL LAYER)
-- =========================================

CREATE OR REPLACE VIEW olist_analytics AS
SELECT * FROM master_olist;

-- ORDER STATUS BY REVENUE
SELECT order_status, SUM(item_price) AS revenue
FROM master_olist
GROUP BY order_status
ORDER BY revenue DESC;


-- CUSTOMER SPENDING BY STATE
SELECT cust_state, SUM(item_price) AS total_revenue
FROM master_olist
GROUP BY cust_state
ORDER BY total_revenue DESC;


-- CUSTOMER COUNT BY REVIEW BUCKET
SELECT 
    ROUND(review_score) AS review_bucket,
    COUNT(customer_id) AS total_customers
FROM master_olist
GROUP BY review_bucket
ORDER BY total_customers DESC;


-- PAYMENT TYPE BY REVENUE
SELECT payment_type, SUM(item_price) AS revenue
FROM master_olist
GROUP BY payment_type
ORDER BY revenue DESC;
SELECT * FROM MASTER_OLIST;

-- TOP CATEGORY BY CARD USERS
SELECT 
    clean_category,
    SUM(item_price) AS total_spent
FROM master_olist
WHERE payment_type = 'credit_card'
GROUP BY clean_category
ORDER BY total_spent DESC;


-- DELIVERY VS REVIEW
SELECT 
    ROUND(review_score) AS review_bucket,
    AVG(delivery_days) AS avg_delivery_days,
    AVG(delay_days) AS avg_delay_days
FROM master_olist
GROUP BY review_bucket
ORDER BY review_bucket DESC;


-- FREIGHT IMPACT ANALYSIS
SELECT 
    CASE 
        WHEN item_freight < 10 THEN 'Low Freight'
        WHEN item_freight BETWEEN 10 AND 30 THEN 'Medium Freight'
        WHEN item_freight BETWEEN 30 AND 60 THEN 'High Freight'
        ELSE 'Very High Freight'
    END AS freight_bucket,
    COUNT(*) AS total_items,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(item_price) AS total_revenue,
    AVG(item_price) AS avg_item_price,
    AVG(item_freight) AS avg_freight
FROM master_olist
GROUP BY freight_bucket
ORDER BY total_orders DESC;

SELECT * FROM MASTER_OLIST;


