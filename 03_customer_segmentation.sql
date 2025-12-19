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
