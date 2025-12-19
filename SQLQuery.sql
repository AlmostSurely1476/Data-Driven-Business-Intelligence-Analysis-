# SQL Scripts for Data-Driven Business Intelligence Analysis
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

-- ============================================================================
-- OLIST E-COMMERCE ANALYSIS
-- Part 3: Customer Segmentation (RFM Analysis)
-- ============================================================================
-- Purpose: Segment customers based on purchasing behavior
-- Skills: Multiple CTEs, NTILE(), CASE Statements, Customer Analytics
-- ============================================================================

USE olist;

-- ----------------------------------------------------------------------------
-- Query 3.1: Complete RFM Segmentation
-- ----------------------------------------------------------------------------
-- RFM = Recency, Frequency, Monetary
-- This is a proven marketing technique for customer segmentation
--
-- Recency: How recently did they purchase? (lower = better)
-- Frequency: How often do they purchase? (higher = better)
-- Monetary: How much do they spend? (higher = better)

WITH customer_rfm AS (
    -- Step 1: Calculate raw RFM values per customer
    SELECT 
        c.customer_unique_id,
        DATEDIFF('2018-09-01', MAX(o.order_purchase_timestamp)) AS recency,
        COUNT(DISTINCT o.order_id) AS frequency,
        ROUND(SUM(oi.price), 2) AS monetary
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_scores AS (
    -- Step 2: Assign scores 1-5 using NTILE (quintiles)
    -- NTILE(5) divides data into 5 equal buckets
    SELECT 
        customer_unique_id,
        recency,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency DESC) AS r_score,  -- DESC because lower recency is better
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM customer_rfm
)
-- Step 3: Create customer segments based on score combinations
SELECT 
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 4 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customers'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Potential Loyalists'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 3 THEN 'Cant Lose Them'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
        ELSE 'Others'
    END AS segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(recency), 0) AS avg_days_since_purchase,
    ROUND(AVG(frequency), 1) AS avg_orders,
    ROUND(AVG(monetary), 2) AS avg_spend
FROM rfm_scores
GROUP BY segment
ORDER BY avg_spend DESC;

-- ----------------------------------------------------------------------------
-- Query 3.2: Customer Lifetime Value by State
-- ----------------------------------------------------------------------------
-- Identify high-value geographic regions

SELECT 
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id) AS total_customers,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(SUM(oi.price) / COUNT(DISTINCT c.customer_unique_id), 2) AS avg_customer_ltv,
    ROUND(COUNT(DISTINCT o.order_id) * 1.0 / 
        COUNT(DISTINCT c.customer_unique_id), 2) AS orders_per_customer
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_revenue DESC
LIMIT 10;

-- ----------------------------------------------------------------------------
-- Query 3.3: Customer Distribution by City (Top 20)
-- ----------------------------------------------------------------------------
-- Find the cities with the most customers

SELECT 
    c.customer_city,
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id) AS total_customers,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_city, c.customer_state
ORDER BY total_customers DESC
LIMIT 20;

-- ----------------------------------------------------------------------------
-- Query 3.4: Repeat Customer Analysis
-- ----------------------------------------------------------------------------
-- What percentage of customers make more than one purchase?

WITH customer_orders AS (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT 
    CASE 
        WHEN order_count = 1 THEN '1 order'
        WHEN order_count = 2 THEN '2 orders'
        WHEN order_count = 3 THEN '3 orders'
        ELSE '4+ orders'
    END AS order_frequency,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM customer_orders
GROUP BY CASE 
    WHEN order_count = 1 THEN '1 order'
    WHEN order_count = 2 THEN '2 orders'
    WHEN order_count = 3 THEN '3 orders'
    ELSE '4+ orders'
END
ORDER BY customer_count DESC;

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

-- ============================================================================
-- OLIST E-COMMERCE ANALYSIS
-- Part 6: Delivery & Operations Analysis
-- ============================================================================
-- Purpose: Evaluate delivery performance and operational efficiency
-- Skills: Date Arithmetic, Conditional Aggregation (CASE in SUM), DATEDIFF
-- ============================================================================

USE olist;

-- ----------------------------------------------------------------------------
-- Query 6.1: Delivery Performance by Month
-- ----------------------------------------------------------------------------
-- Track on-time delivery rates and average delivery times over time
-- Uses CASE inside SUM for conditional counting

SELECT 
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS month,
    COUNT(*) AS total_orders,
    SUM(CASE 
        WHEN order_delivered_customer_date <= order_estimated_delivery_date 
        THEN 1 ELSE 0 
    END) AS on_time_deliveries,
    SUM(CASE 
        WHEN order_delivered_customer_date > order_estimated_delivery_date 
        THEN 1 ELSE 0 
    END) AS late_deliveries,
    ROUND(
        SUM(CASE 
            WHEN order_delivered_customer_date <= order_estimated_delivery_date 
            THEN 1 ELSE 0 
        END) * 100.0 / COUNT(*), 2
    ) AS on_time_pct,
    ROUND(AVG(
        DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)
    ), 1) AS avg_delivery_days,
    ROUND(AVG(
        DATEDIFF(order_estimated_delivery_date, order_purchase_timestamp)
    ), 1) AS avg_estimated_days
FROM orders
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
ORDER BY month;

-- ----------------------------------------------------------------------------
-- Query 6.2: Delivery Performance by Customer State
-- ----------------------------------------------------------------------------
-- Identify regions with delivery challenges

SELECT 
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(
        DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)
    ), 1) AS avg_delivery_days,
    ROUND(
        SUM(CASE 
            WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date 
            THEN 1 ELSE 0 
        END) * 100.0 / COUNT(*), 2
    ) AS on_time_pct,
    ROUND(AVG(r.review_score), 2) AS avg_review
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
HAVING COUNT(DISTINCT o.order_id) >= 100
ORDER BY avg_delivery_days ASC;

-- ----------------------------------------------------------------------------
-- Query 6.3: Payment Method Analysis
-- ----------------------------------------------------------------------------
-- Understand payment preferences and behavior

SELECT 
    payment_type,
    COUNT(*) AS transaction_count,
    COUNT(DISTINCT order_id) AS unique_orders,
    ROUND(SUM(payment_value), 2) AS total_value,
    ROUND(AVG(payment_value), 2) AS avg_transaction,
    ROUND(AVG(payment_installments), 1) AS avg_installments,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_transactions
FROM order_payments
GROUP BY payment_type
ORDER BY transaction_count DESC;

-- ----------------------------------------------------------------------------
-- Query 6.4: Installment Payment Analysis
-- ----------------------------------------------------------------------------
-- How do customers use installment payments?

SELECT 
    payment_installments,
    COUNT(*) AS order_count,
    ROUND(AVG(payment_value), 2) AS avg_order_value,
    ROUND(SUM(payment_value), 2) AS total_value,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM order_payments
WHERE payment_type = 'credit_card'
GROUP BY payment_installments
ORDER BY payment_installments;

-- ----------------------------------------------------------------------------
-- Query 6.5: Delivery Time vs Review Score Correlation
-- ----------------------------------------------------------------------------
-- Does faster delivery lead to better reviews?

SELECT 
    CASE 
        WHEN DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) <= 7 
            THEN '1-7 days'
        WHEN DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) <= 14 
            THEN '8-14 days'
        WHEN DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) <= 21 
            THEN '15-21 days'
        WHEN DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) <= 30 
            THEN '22-30 days'
        ELSE '30+ days'
    END AS delivery_time_bucket,
    COUNT(*) AS order_count,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    SUM(CASE WHEN r.review_score >= 4 THEN 1 ELSE 0 END) AS positive_reviews,
    SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) AS negative_reviews
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
GROUP BY CASE 
    WHEN DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) <= 7 
        THEN '1-7 days'
    WHEN DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) <= 14 
        THEN '8-14 days'
    WHEN DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) <= 21 
        THEN '15-21 days'
    WHEN DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) <= 30 
        THEN '22-30 days'
    ELSE '30+ days'
END
ORDER BY avg_review_score DESC;

-- ----------------------------------------------------------------------------
-- Query 6.6: Order Fulfillment Funnel
-- ----------------------------------------------------------------------------
-- Track orders through each stage of fulfillment

SELECT 
    'Total Orders' AS stage,
    COUNT(*) AS order_count,
    100.0 AS percentage
FROM orders

UNION ALL

SELECT 
    'Approved' AS stage,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 2)
FROM orders
WHERE order_approved_at IS NOT NULL

UNION ALL

SELECT 
    'Shipped' AS stage,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 2)
FROM orders
WHERE order_delivered_carrier_date IS NOT NULL

UNION ALL

SELECT 
    'Delivered' AS stage,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 2)
FROM orders
WHERE order_delivered_customer_date IS NOT NULL;

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
