# Data-Driven Business Intelligence Analysis

**Business Tasks**
1. What is the overall health of the business?
2. How is revenue trending over time?
3. Who are our most valuable customers?
4. Which sellers perform best?
5. What product categories drive the most value?
6. How efficient is our delivery operation?

**Data Set**
- Brazilian e-commerce data from [Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

## Part 1: Executive Dashboard Insights

### Key Metrics
| Metric | Value |
|--------|-------|
| Total Delivered Orders | 86,455 |
| Unique Customers | 86,455 |
| Active Sellers | 2,970 |
| Products Sold | 32,210 |
| Total Revenue | R$ 13.3 million |
| Average Order Value | R$ 119.81 |
| Average Review Score | 4.08 / 5.0 |

### Key Insight
The 1:1 ratio of orders to unique customers suggests **very low repeat purchase rate**. This indicates either:
- Customers are one-time buyers
- The customer_id field may represent order-level rather than customer-level data

**Recommendation:** Focus on customer retention strategies to improve lifetime value.

---

## Part 2: Revenue Analysis Insights

### Growth Trends
- Revenue showed **strong month-over-month growth** throughout 2017
- **November 2017** showed exceptional growth (Black Friday effect)
- Growth began stabilizing in early 2018

### Revenue Concentration
- **Top 5 categories** generate approximately 35% of total revenue
- Categories: Health & Beauty, Watches, Bed/Bath/Table, Sports/Leisure, Computers

### Timing Patterns
- **Peak ordering days:** Monday through Wednesday
- **Peak hours:** 10 AM - 4 PM (business hours)
- Weekend orders are 20-30% lower than weekdays

**Recommendation:** Schedule marketing campaigns for Monday mornings; consider weekend promotions to balance demand.

---

## Part 3: Customer Segmentation Insights

### RFM Segments Identified

| Segment | % of Customers | Avg Spend | Strategy |
|---------|---------------|-----------|----------|
| Champions | ~5% | R$ 287 | Reward & retain |
| Loyal Customers | ~15% | R$ 198 | Upsell opportunities |
| New Customers | ~25% | R$ 142 | Nurture to loyalty |
| At Risk | ~10% | R$ 157 | Win-back campaigns |
| Lost | ~20% | R$ 89 | Re-engagement offers |

### Geographic Distribution
- **São Paulo (SP)** dominates with 42% of orders
- **Rio de Janeiro (RJ)** is second with 13%
- **Minas Gerais (MG)** third with 12%
- Southeast region accounts for 70%+ of all orders

**Recommendation:** Prioritize logistics infrastructure in SP, RJ, MG. Consider expansion strategies for underserved regions.

---

## Part 4: Seller Performance Insights

### Seller Distribution
- Total active sellers: 2,970
- **São Paulo state** has the most sellers (60%+)
- Top 10% of sellers generate approximately 50% of revenue

### Performance Correlation
- Sellers with **faster delivery** tend to have **higher reviews**
- **Gold tier sellers** (high revenue + high reviews) are rare but highly valuable
- Average seller fulfills ~30 orders during the data period

**Recommendation:** Create seller incentive programs based on composite scores. Recruit more sellers in underrepresented states.

---

## Part 5: Product Strategy Insights

### Category Classification

**Stars (High Volume + High Value):**
- Computers & Accessories
- Watches & Gifts
- Health & Beauty

**Cash Cows (High Volume + Lower Value):**
- Bed/Bath/Table
- Sports & Leisure
- Furniture

**Niche (Premium Price):**
- Office Furniture
- Musical Instruments
- Electronics

### Freight Impact
- Heavier categories (Furniture, Appliances) have freight costs of 15-25% of item price
- Lighter categories (Watches, Beauty) have freight costs of 8-12%

**Recommendation:** Consider free shipping thresholds for high-margin categories. Optimize logistics for heavy items.

---

## Part 6: Operations Insights

### Delivery Performance
- **On-time delivery rate:** ~92%
- **Average delivery time:** 12 days
- **Estimated vs Actual:** Olist tends to over-estimate delivery times (under-promise, over-deliver)

### Regional Variations
- **Fastest delivery:** São Paulo, Paraná (7-10 days)
- **Slowest delivery:** Northern states (20+ days)
- Delivery time **strongly correlates** with review scores

### Delivery Time vs Reviews
| Delivery Time | Avg Review |
|---------------|------------|
| 1-7 days | 4.4 |
| 8-14 days | 4.2 |
| 15-21 days | 3.8 |
| 22-30 days | 3.4 |
| 30+ days | 2.8 |

### Payment Methods
- **Credit Card:** 74% of transactions (avg 3.5 installments)
- **Boleto (bank slip):** 19%
- **Voucher:** 5%
- **Debit:** 2%

**Recommendation:** Prioritize delivery speed improvements in slow regions. Consider regional warehousing.

---

## Part 7: Advanced Analytics Insights

### Customer Retention
- Repeat purchase rate is very low (~3%)
- When customers do return, it's typically within 60-90 days
- No significant cohort showed strong retention

### Year-over-Year Growth (2017 vs 2018)
- Orders grew **50-100%** year-over-year in most months
- Revenue growth was even stronger due to higher order values

### Pareto Analysis (80/20 Rule)
- **Top 10% of products** generate approximately **60% of revenue**
- **Top 20% of products** generate approximately **75% of revenue**
- Classic Pareto distribution confirmed

### Same-State Orders
- Orders where seller and customer are in the **same state** deliver **3-4 days faster**
- Same-state orders have **lower freight costs** and **higher reviews**

**Recommendation:** Implement smart seller matching to prioritize same-state fulfillment when possible.

  
