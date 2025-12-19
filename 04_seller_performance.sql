-- ============================================================================
-- OLIST E-COMMERCE ANALYSIS
-- Part 4: Seller Performance Scorecard
-- ============================================================================
-- Purpose: Rank and evaluate seller performance using multiple metrics
-- Skills: DENSE_RANK(), Complex Scoring Algorithms, HAVING, Normalization
-- ============================================================================

USE olist;

-- ----------------------------------------------------------------------------
-- Query 4.1: Seller Performance Metrics
-- ----------------------------------------------------------------------------
-- Calculate key metrics and rank sellers across multiple dimensions
-- DENSE_RANK allows ties without gaps (1,2,2,3 instead of 1,2,2,4)

WITH seller_metrics AS (
    SELECT 
        s.seller_id,
        s.seller_city,
        s.seller_state,
        COUNT(DISTINCT oi.order_id) AS orders_fulfilled,
        COUNT(DISTINCT oi.product_id) AS unique_products,
        ROUND(SUM(oi.price), 2) AS total_revenue,
        ROUND(AVG(oi.price), 2) AS avg_item_price,
        ROUND(AVG(r.review_score), 2) AS avg_review_score,
        ROUND(AVG(
            DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)
        ), 1) AS avg_delivery_days
    FROM sellers s
    JOIN order_items oi ON s.seller_id = oi.seller_id
    JOIN orders o ON oi.order_id = o.order_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY s.seller_id, s.seller_city, s.seller_state
    HAVING COUNT(DISTINCT oi.order_id) >= 10  -- Only sellers with 10+ orders
)
SELECT 
    seller_id,
    seller_city,
    seller_state,
    orders_fulfilled,
    total_revenue,
    avg_review_score,
    avg_delivery_days,
    DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
    DENSE_RANK() OVER (ORDER BY avg_review_score DESC) AS review_rank,
    DENSE_RANK() OVER (ORDER BY avg_delivery_days ASC) AS delivery_rank
FROM seller_metrics
ORDER BY total_revenue DESC
LIMIT 20;

-- ----------------------------------------------------------------------------
-- Query 4.2: Composite Seller Score (Weighted Algorithm)
-- ----------------------------------------------------------------------------
-- Creates a normalized 0-100 score for each metric
-- Combines into weighted composite score:
--   40% Revenue + 35% Reviews + 25% Delivery Speed

WITH seller_metrics AS (
    SELECT 
        s.seller_id,
        s.seller_state,
        COUNT(DISTINCT oi.order_id) AS orders_fulfilled,
        SUM(oi.price) AS total_revenue,
        AVG(r.review_score) AS avg_review,
        AVG(DATEDIFF(o.order_delivered_customer_date, 
            o.order_purchase_timestamp)) AS avg_delivery_days
    FROM sellers s
    JOIN order_items oi ON s.seller_id = oi.seller_id
    JOIN orders o ON oi.order_id = o.order_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY s.seller_id, s.seller_state
    HAVING COUNT(DISTINCT oi.order_id) >= 10
),
normalized_scores AS (
    SELECT *,
        -- Normalize each metric to 0-100 scale using min-max normalization
        (total_revenue - MIN(total_revenue) OVER()) / 
            (MAX(total_revenue) OVER() - MIN(total_revenue) OVER()) * 100 
            AS revenue_score,
        (avg_review - MIN(avg_review) OVER()) / 
            (MAX(avg_review) OVER() - MIN(avg_review) OVER()) * 100 
            AS review_score,
        -- Invert delivery score (lower days = higher score)
        100 - (avg_delivery_days - MIN(avg_delivery_days) OVER()) / 
            (MAX(avg_delivery_days) OVER() - MIN(avg_delivery_days) OVER()) * 100 
            AS delivery_score
    FROM seller_metrics
)
SELECT 
    seller_id,
    seller_state,
    orders_fulfilled,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(avg_review, 2) AS avg_review,
    ROUND(avg_delivery_days, 1) AS avg_delivery_days,
    -- Weighted composite: 40% revenue, 35% reviews, 25% delivery
    ROUND(revenue_score * 0.40 + review_score * 0.35 + 
        delivery_score * 0.25, 2) AS composite_score
FROM normalized_scores
ORDER BY composite_score DESC
LIMIT 15;

-- ----------------------------------------------------------------------------
-- Query 4.3: Seller Distribution by State
-- ----------------------------------------------------------------------------
-- Geographic distribution of sellers

SELECT 
    s.seller_state,
    COUNT(DISTINCT s.seller_id) AS seller_count,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(AVG(r.review_score), 2) AS avg_review
FROM sellers s
JOIN order_items oi ON s.seller_id = oi.seller_id
JOIN orders o ON oi.order_id = o.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_state
ORDER BY total_revenue DESC;

-- ----------------------------------------------------------------------------
-- Query 4.4: Seller Performance Tiers
-- ----------------------------------------------------------------------------
-- Categorize sellers into performance tiers

WITH seller_stats AS (
    SELECT 
        s.seller_id,
        COUNT(DISTINCT oi.order_id) AS orders,
        SUM(oi.price) AS revenue,
        AVG(r.review_score) AS avg_review
    FROM sellers s
    JOIN order_items oi ON s.seller_id = oi.seller_id
    JOIN orders o ON oi.order_id = o.order_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY s.seller_id
),
seller_tiers AS (
    SELECT *,
        NTILE(4) OVER (ORDER BY revenue) AS revenue_tier,
        NTILE(4) OVER (ORDER BY avg_review) AS review_tier
    FROM seller_stats
    WHERE orders >= 5
)
SELECT 
    CASE 
        WHEN revenue_tier = 4 AND review_tier >= 3 THEN 'Gold'
        WHEN revenue_tier >= 3 AND review_tier >= 3 THEN 'Silver'
        WHEN revenue_tier >= 2 OR review_tier >= 2 THEN 'Bronze'
        ELSE 'Standard'
    END AS tier,
    COUNT(*) AS seller_count,
    ROUND(AVG(revenue), 2) AS avg_revenue,
    ROUND(AVG(orders), 1) AS avg_orders,
    ROUND(AVG(avg_review), 2) AS avg_review_score
FROM seller_tiers
GROUP BY 
    CASE 
        WHEN revenue_tier = 4 AND review_tier >= 3 THEN 'Gold'
        WHEN revenue_tier >= 3 AND review_tier >= 3 THEN 'Silver'
        WHEN revenue_tier >= 2 OR review_tier >= 2 THEN 'Bronze'
        ELSE 'Standard'
    END
ORDER BY avg_revenue DESC;
