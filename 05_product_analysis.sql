-- ============================================================================
-- OLIST E-COMMERCE ANALYSIS
-- Part 5: Product & Category Strategy
-- ============================================================================
-- Purpose: Analyze product performance and identify strategic opportunities
-- Skills: Comparative Analysis, COALESCE, Percentage Calculations, NTILE
-- ============================================================================

USE olist;

-- ----------------------------------------------------------------------------
-- Query 5.1: Category Performance Matrix
-- ----------------------------------------------------------------------------
-- Complete performance metrics for each product category
-- Includes revenue, reviews, and freight analysis

SELECT 
    COALESCE(ct.product_category_name_english, 'Unknown') AS category,
    COUNT(DISTINCT oi.order_id) AS order_count,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(AVG(oi.price), 2) AS avg_price,
    ROUND(AVG(r.review_score), 2) AS avg_review,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight,
    ROUND(AVG(oi.freight_value) / AVG(oi.price) * 100, 2) AS freight_pct_of_price
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN category_translation ct 
    ON p.product_category_name = ct.product_category_name
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY ct.product_category_name_english
HAVING COUNT(DISTINCT oi.order_id) >= 100
ORDER BY total_revenue DESC
LIMIT 20;

-- ----------------------------------------------------------------------------
-- Query 5.2: High-Value vs High-Volume Categories (BCG Matrix Style)
-- ----------------------------------------------------------------------------
-- Categorize products using a strategic framework:
-- - Stars: High volume + High value
-- - Cash Cows: High volume + Low value  
-- - Niche: Low volume + Premium price
-- - Question Marks: Low volume + Low value

WITH category_stats AS (
    SELECT 
        COALESCE(ct.product_category_name_english, 'Unknown') AS category,
        COUNT(DISTINCT oi.order_id) AS orders,
        SUM(oi.price) AS revenue,
        AVG(oi.price) AS avg_price
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct 
        ON p.product_category_name = ct.product_category_name
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY ct.product_category_name_english
    HAVING COUNT(DISTINCT oi.order_id) >= 50
),
category_percentiles AS (
    SELECT *,
        NTILE(4) OVER (ORDER BY orders) AS volume_quartile,
        NTILE(4) OVER (ORDER BY avg_price) AS price_quartile
    FROM category_stats
)
SELECT 
    category,
    orders,
    ROUND(revenue, 2) AS revenue,
    ROUND(avg_price, 2) AS avg_price,
    CASE 
        WHEN volume_quartile = 4 AND price_quartile >= 3 
            THEN 'Star (High Volume + High Value)'
        WHEN volume_quartile = 4 AND price_quartile <= 2 
            THEN 'Cash Cow (High Volume + Low Value)'
        WHEN volume_quartile <= 2 AND price_quartile = 4 
            THEN 'Niche (Low Volume + Premium Price)'
        WHEN volume_quartile <= 2 AND price_quartile <= 2 
            THEN 'Question Mark (Low Volume + Low Value)'
        ELSE 'Moderate'
    END AS category_type
FROM category_percentiles
ORDER BY revenue DESC;

-- ----------------------------------------------------------------------------
-- Query 5.3: Top Products by Revenue
-- ----------------------------------------------------------------------------
-- Find the individual best-selling products

SELECT 
    p.product_id,
    COALESCE(ct.product_category_name_english, 'Unknown') AS category,
    COUNT(DISTINCT oi.order_id) AS times_sold,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(AVG(oi.price), 2) AS avg_price,
    ROUND(AVG(r.review_score), 2) AS avg_review
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN category_translation ct 
    ON p.product_category_name = ct.product_category_name
JOIN orders o ON oi.order_id = o.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY p.product_id, ct.product_category_name_english
ORDER BY total_revenue DESC
LIMIT 20;

-- ----------------------------------------------------------------------------
-- Query 5.4: Category Growth Analysis
-- ----------------------------------------------------------------------------
-- Compare category performance between time periods

WITH period_sales AS (
    SELECT 
        COALESCE(ct.product_category_name_english, 'Unknown') AS category,
        CASE 
            WHEN o.order_purchase_timestamp < '2018-01-01' THEN 'Period_1_2017'
            ELSE 'Period_2_2018'
        END AS period,
        SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct 
        ON p.product_category_name = ct.product_category_name
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
        AND o.order_purchase_timestamp >= '2017-01-01'
    GROUP BY ct.product_category_name_english,
        CASE 
            WHEN o.order_purchase_timestamp < '2018-01-01' THEN 'Period_1_2017'
            ELSE 'Period_2_2018'
        END
)
SELECT 
    p1.category,
    ROUND(p1.revenue, 2) AS revenue_2017,
    ROUND(p2.revenue, 2) AS revenue_2018,
    ROUND((p2.revenue - p1.revenue) / p1.revenue * 100, 2) AS growth_pct
FROM period_sales p1
JOIN period_sales p2 ON p1.category = p2.category
WHERE p1.period = 'Period_1_2017' 
    AND p2.period = 'Period_2_2018'
    AND p1.revenue > 10000  -- Only categories with meaningful 2017 sales
ORDER BY growth_pct DESC
LIMIT 15;

-- ----------------------------------------------------------------------------
-- Query 5.5: Product Weight vs Price Analysis
-- ----------------------------------------------------------------------------
-- Understand relationship between physical attributes and pricing

SELECT 
    COALESCE(ct.product_category_name_english, 'Unknown') AS category,
    COUNT(*) AS product_count,
    ROUND(AVG(p.product_weight_g), 0) AS avg_weight_grams,
    ROUND(AVG(oi.price), 2) AS avg_price,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight,
    ROUND(AVG(oi.freight_value) / NULLIF(AVG(p.product_weight_g), 0) * 1000, 2) 
        AS freight_per_kg
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN category_translation ct 
    ON p.product_category_name = ct.product_category_name
WHERE p.product_weight_g IS NOT NULL
    AND p.product_weight_g > 0
GROUP BY ct.product_category_name_english
HAVING COUNT(*) >= 50
ORDER BY avg_weight_grams DESC
LIMIT 15;
