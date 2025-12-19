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
