-- ============================================================================
-- OLIST E-COMMERCE ANALYSIS
-- Part 1: Executive Dashboard
-- ============================================================================
-- Purpose: Provide a high-level overview of business performance
-- Skills: JOINs, Aggregations, Date Functions
-- ============================================================================

USE olist;

-- ----------------------------------------------------------------------------
-- Query 1.1: Complete Business Overview
-- ----------------------------------------------------------------------------
-- This query provides a single-row snapshot of the entire business
-- Useful for executive dashboards and KPI reporting

SELECT 
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS total_customers,
    COUNT(DISTINCT oi.seller_id) AS active_sellers,
    COUNT(DISTINCT oi.product_id) AS products_sold,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(SUM(oi.freight_value), 2) AS total_freight,
    ROUND(AVG(oi.price), 2) AS avg_order_value,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    MIN(DATE(o.order_purchase_timestamp)) AS first_order_date,
    MAX(DATE(o.order_purchase_timestamp)) AS last_order_date
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered';

-- ----------------------------------------------------------------------------
-- Query 1.2: Monthly Performance Summary
-- ----------------------------------------------------------------------------
-- Track key metrics over time to identify trends and seasonality
-- GROUP BY month to see progression

SELECT 
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
    COUNT(DISTINCT o.order_id) AS orders,
    COUNT(DISTINCT o.customer_id) AS customers,
    ROUND(SUM(oi.price), 2) AS revenue,
    ROUND(AVG(oi.price), 2) AS avg_order_value,
    ROUND(AVG(r.review_score), 2) AS avg_review
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
ORDER BY month;

-- ----------------------------------------------------------------------------
-- Query 1.3: Order Status Distribution
-- ----------------------------------------------------------------------------
-- Understand the breakdown of order statuses
-- Helps identify fulfillment issues

SELECT 
    order_status,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;
