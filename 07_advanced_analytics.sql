-- ============================================================================
-- OLIST E-COMMERCE ANALYSIS
-- Part 7: Advanced Analytics
-- ============================================================================
-- Purpose: Demonstrate mastery-level SQL techniques
-- Skills: Cohort Analysis, YoY Comparison, Complex Date Logic, Self-Joins
-- ============================================================================

USE olist;

-- ----------------------------------------------------------------------------
-- Query 7.1: Cohort Retention Analysis
-- ----------------------------------------------------------------------------
-- Track how customers from each monthly cohort return over time
-- This is a classic retention analysis used by top tech companies

WITH first_purchase AS (
    -- Step 1: Find each customer's first purchase month (their "cohort")
    SELECT 
        c.customer_unique_id,
        DATE_FORMAT(MIN(o.order_purchase_timestamp), '%Y-%m') AS cohort_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
customer_orders AS (
    -- Step 2: Get all orders with cohort information
    SELECT 
        c.customer_unique_id,
        fp.cohort_month,
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN first_purchase fp ON c.customer_unique_id = fp.customer_unique_id
    WHERE o.order_status = 'delivered'
)
-- Step 3: Count customers active in each month after their cohort
SELECT 
    cohort_month,
    COUNT(DISTINCT customer_unique_id) AS cohort_size,
    COUNT(DISTINCT CASE 
        WHEN order_month = cohort_month THEN customer_unique_id 
    END) AS month_0,
    COUNT(DISTINCT CASE 
        WHEN order_month = DATE_FORMAT(
            DATE_ADD(STR_TO_DATE(CONCAT(cohort_month, '-01'), '%Y-%m-%d'), 
            INTERVAL 1 MONTH), '%Y-%m') 
        THEN customer_unique_id 
    END) AS month_1,
    COUNT(DISTINCT CASE 
        WHEN order_month = DATE_FORMAT(
            DATE_ADD(STR_TO_DATE(CONCAT(cohort_month, '-01'), '%Y-%m-%d'), 
            INTERVAL 2 MONTH), '%Y-%m') 
        THEN customer_unique_id 
    END) AS month_2,
    COUNT(DISTINCT CASE 
        WHEN order_month = DATE_FORMAT(
            DATE_ADD(STR_TO_DATE(CONCAT(cohort_month, '-01'), '%Y-%m-%d'), 
            INTERVAL 3 MONTH), '%Y-%m') 
        THEN customer_unique_id 
    END) AS month_3
FROM customer_orders
WHERE cohort_month >= '2017-01' AND cohort_month <= '2018-06'
GROUP BY cohort_month
ORDER BY cohort_month;

-- ----------------------------------------------------------------------------
-- Query 7.2: Year-over-Year Comparison
-- ----------------------------------------------------------------------------
-- Compare 2017 vs 2018 performance by month
-- Uses self-join to align months across years

WITH monthly_data AS (
    SELECT 
        YEAR(o.order_purchase_timestamp) AS year,
        MONTH(o.order_purchase_timestamp) AS month,
        COUNT(DISTINCT o.order_id) AS orders,
        SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY YEAR(o.order_purchase_timestamp), 
        MONTH(o.order_purchase_timestamp)
)
SELECT 
    m2018.month,
    m2017.orders AS orders_2017,
    m2018.orders AS orders_2018,
    ROUND((m2018.orders - m2017.orders) * 100.0 / m2017.orders, 2) 
        AS order_growth_pct,
    ROUND(m2017.revenue, 2) AS revenue_2017,
    ROUND(m2018.revenue, 2) AS revenue_2018,
    ROUND((m2018.revenue - m2017.revenue) * 100.0 / m2017.revenue, 2) 
        AS revenue_growth_pct
FROM monthly_data m2018
JOIN monthly_data m2017 
    ON m2018.month = m2017.month 
    AND m2018.year = 2018 
    AND m2017.year = 2017
ORDER BY m2018.month;

-- ----------------------------------------------------------------------------
-- Query 7.3: Customer Purchase Gap Analysis
-- ----------------------------------------------------------------------------
-- How long between a customer's first and second purchase?

WITH customer_orders AS (
    SELECT 
        c.customer_unique_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id 
            ORDER BY o.order_purchase_timestamp
        ) AS order_number
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
purchase_gaps AS (
    SELECT 
        co1.customer_unique_id,
        co1.order_purchase_timestamp AS first_purchase,
        co2.order_purchase_timestamp AS second_purchase,
        DATEDIFF(co2.order_purchase_timestamp, co1.order_purchase_timestamp) AS days_between
    FROM customer_orders co1
    JOIN customer_orders co2 
        ON co1.customer_unique_id = co2.customer_unique_id
        AND co1.order_number = 1
        AND co2.order_number = 2
)
SELECT 
    CASE 
        WHEN days_between <= 30 THEN '0-30 days'
        WHEN days_between <= 60 THEN '31-60 days'
        WHEN days_between <= 90 THEN '61-90 days'
        WHEN days_between <= 180 THEN '91-180 days'
        ELSE '180+ days'
    END AS gap_bucket,
    COUNT(*) AS customer_count,
    ROUND(AVG(days_between), 1) AS avg_days
FROM purchase_gaps
GROUP BY CASE 
    WHEN days_between <= 30 THEN '0-30 days'
    WHEN days_between <= 60 THEN '31-60 days'
    WHEN days_between <= 90 THEN '61-90 days'
    WHEN days_between <= 180 THEN '91-180 days'
    ELSE '180+ days'
END
ORDER BY avg_days;

-- ----------------------------------------------------------------------------
-- Query 7.4: Seller-Customer State Match Analysis
-- ----------------------------------------------------------------------------
-- Do orders ship faster when seller and customer are in the same state?

SELECT 
    CASE 
        WHEN c.customer_state = s.seller_state THEN 'Same State'
        ELSE 'Different State'
    END AS location_match,
    COUNT(DISTINCT o.order_id) AS order_count,
    ROUND(AVG(
        DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)
    ), 1) AS avg_delivery_days,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight,
    ROUND(AVG(r.review_score), 2) AS avg_review
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
GROUP BY CASE 
    WHEN c.customer_state = s.seller_state THEN 'Same State'
    ELSE 'Different State'
END;

-- ----------------------------------------------------------------------------
-- Query 7.5: Revenue Concentration (Pareto Analysis)
-- ----------------------------------------------------------------------------
-- Do 20% of products generate 80% of revenue? (Pareto Principle)

WITH product_revenue AS (
    SELECT 
        oi.product_id,
        SUM(oi.price) AS revenue,
        ROW_NUMBER() OVER (ORDER BY SUM(oi.price) DESC) AS revenue_rank
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.product_id
),
total_stats AS (
    SELECT 
        COUNT(*) AS total_products,
        SUM(revenue) AS total_revenue
    FROM product_revenue
)
SELECT 
    CASE 
        WHEN pr.revenue_rank <= ts.total_products * 0.1 THEN 'Top 10%'
        WHEN pr.revenue_rank <= ts.total_products * 0.2 THEN 'Top 11-20%'
        WHEN pr.revenue_rank <= ts.total_products * 0.5 THEN 'Top 21-50%'
        ELSE 'Bottom 50%'
    END AS product_tier,
    COUNT(*) AS product_count,
    ROUND(SUM(pr.revenue), 2) AS tier_revenue,
    ROUND(SUM(pr.revenue) * 100.0 / ts.total_revenue, 2) AS revenue_pct
FROM product_revenue pr
CROSS JOIN total_stats ts
GROUP BY CASE 
    WHEN pr.revenue_rank <= ts.total_products * 0.1 THEN 'Top 10%'
    WHEN pr.revenue_rank <= ts.total_products * 0.2 THEN 'Top 11-20%'
    WHEN pr.revenue_rank <= ts.total_products * 0.5 THEN 'Top 21-50%'
    ELSE 'Bottom 50%'
END, ts.total_revenue
ORDER BY revenue_pct DESC;

-- ----------------------------------------------------------------------------
-- Query 7.6: Review Score Distribution Analysis
-- ----------------------------------------------------------------------------
-- Deep dive into customer satisfaction patterns

SELECT 
    r.review_score,
    COUNT(*) AS review_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage,
    ROUND(AVG(oi.price), 2) AS avg_order_value,
    ROUND(AVG(
        DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)
    ), 1) AS avg_delivery_days
FROM order_reviews r
JOIN orders o ON r.order_id = o.order_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
GROUP BY r.review_score
ORDER BY r.review_score DESC;
