-- ============================================================================
-- OLIST E-COMMERCE ANALYSIS
-- Part 2: Revenue Deep-Dive
-- ============================================================================
-- Purpose: Analyze revenue trends, growth rates, and patterns
-- Skills: Window Functions (LAG, SUM OVER), CTEs, Date Functions
-- ============================================================================

USE olist;

-- ----------------------------------------------------------------------------
-- Query 2.1: Month-over-Month Revenue Growth
-- ----------------------------------------------------------------------------
-- Uses LAG() window function to compare each month to the previous month
-- CTEs make the query readable and maintainable

WITH monthly_revenue AS (
    SELECT 
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
        SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
)
SELECT 
    month,
    ROUND(revenue, 2) AS revenue,
    ROUND(LAG(revenue) OVER (ORDER BY month), 2) AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month)) / 
        LAG(revenue) OVER (ORDER BY month) * 100, 
    2) AS growth_rate_pct
FROM monthly_revenue
ORDER BY month;

-- ----------------------------------------------------------------------------
-- Query 2.2: Cumulative Revenue & Moving Average
-- ----------------------------------------------------------------------------
-- Running total shows business growth trajectory
-- 3-month moving average smooths out fluctuations

WITH monthly_revenue AS (
    SELECT 
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
        SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
)
SELECT 
    month,
    ROUND(revenue, 2) AS monthly_revenue,
    ROUND(SUM(revenue) OVER (ORDER BY month), 2) AS cumulative_revenue,
    ROUND(AVG(revenue) OVER (
        ORDER BY month 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS three_month_moving_avg
FROM monthly_revenue
ORDER BY month;

-- ----------------------------------------------------------------------------
-- Query 2.3: Revenue by Product Category
-- ----------------------------------------------------------------------------
-- Identify top-performing categories
-- Includes revenue share percentage using subquery

SELECT 
    COALESCE(ct.product_category_name_english, 'Unknown') AS category,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(AVG(oi.price), 2) AS avg_item_price,
    ROUND(SUM(oi.price) * 100.0 / 
        (SELECT SUM(price) FROM order_items), 2) AS revenue_share_pct
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN category_translation ct 
    ON p.product_category_name = ct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY ct.product_category_name_english
ORDER BY total_revenue DESC
LIMIT 15;

-- ----------------------------------------------------------------------------
-- Query 2.4: Revenue by Day of Week
-- ----------------------------------------------------------------------------
-- Understand purchasing patterns throughout the week

SELECT 
    DAYNAME(o.order_purchase_timestamp) AS day_of_week,
    DAYOFWEEK(o.order_purchase_timestamp) AS day_number,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.price), 2) AS revenue,
    ROUND(AVG(oi.price), 2) AS avg_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DAYNAME(o.order_purchase_timestamp), DAYOFWEEK(o.order_purchase_timestamp)
ORDER BY day_number;

-- ----------------------------------------------------------------------------
-- Query 2.5: Revenue by Hour of Day
-- ----------------------------------------------------------------------------
-- Find peak purchasing hours for marketing optimization

SELECT 
    HOUR(o.order_purchase_timestamp) AS hour_of_day,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.price), 2) AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY HOUR(o.order_purchase_timestamp)
ORDER BY hour_of_day;
