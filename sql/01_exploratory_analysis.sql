-- ============================================================
-- E-COMMERCE USER BEHAVIOR ANALYSIS
-- Exploratory SQL queries
-- Platform: Google BigQuery
-- Source table: ecommerce_analytics.events_partitioned
-- Analysis period: October–November 2019
-- ============================================================


-- ============================================================
-- 1. USER ENGAGEMENT
-- ============================================================

-- 1.1 Monthly Active Users
-- Calculates distinct active users by month and month-over-month growth.
WITH monthly_active_users AS (
  SELECT
    DATE_TRUNC(DATE(event_time), MONTH) AS month,
    COUNT(DISTINCT user_id) AS mau
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  GROUP BY month
)

SELECT
  month,
  mau,
  ROUND(
    100 * (mau - LAG(mau) OVER (ORDER BY month)) 
    / LAG(mau) OVER (ORDER BY month),
    2
  ) AS mau_growth_pct
FROM monthly_active_users
ORDER BY month;

-- 1.2 Weekly Active Users
-- Calculates distinct active users by week and week-over-week growth.
WITH weekly_active_users AS (
  SELECT
    DATE_TRUNC(DATE(event_time), WEEK(MONDAY)) AS week_start,
    COUNT(DISTINCT user_id) AS wau
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  GROUP BY week_start
)

SELECT
  week_start,
  wau,
  ROUND(
    100 * (wau - LAG(wau) OVER (ORDER BY week_start))
    / LAG(wau) OVER (ORDER BY week_start),
    2
  ) AS wau_growth_pct
FROM weekly_active_users
ORDER BY week_start;

-- 1.3 Daily Active Users
-- Calculates distinct active users for each day.
SELECT
  DATE(event_time) AS event_date,
  COUNT(DISTINCT user_id) AS DAU
FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
GROUP BY event_date
ORDER BY event_date;

-- 1.4 Top Days by Engagement
-- Identifies the days with the highest number of active users.
SELECT
  DATE(event_time) AS event_date,
  COUNT(*) AS total_events,
  COUNT(DISTINCT user_id) AS active_users
FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
GROUP BY event_date
ORDER BY active_users DESC
LIMIT 10;

-- 1.5 User Activity by Hour
-- Identifies the most active hours of the day.
SELECT
  EXTRACT(HOUR FROM event_time) AS hour_of_day,
  COUNT(*) AS total_events,
  COUNT(DISTINCT user_id) AS active_users
FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned` 
GROUP BY hour_of_day
ORDER BY active_users DESC;

-- 1.6 Weekday vs Weekend Performance
-- Compares engagement, purchases, and revenue between weekdays and weekends.
SELECT
  CASE
    WHEN EXTRACT(DAYOFWEEK FROM event_time) IN (1,7) THEN 'weekend' ELSE 'weekday' 
  END AS day_type,
  COUNT(*) AS total_events,
  COUNT(DISTINCT user_id) AS active_users,
  COUNTIF(event_type = 'purchase') AS purchases,
  ROUND(SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END), 2) AS revenue
FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
GROUP BY day_type
ORDER BY revenue DESC;

-- ============================================================
-- 2. REVENUE AND CONVERSION
-- ============================================================

-- 2.1 Unique Buyers
-- Calculates the number of distinct purchasing users by month.
SELECT
  FORMAT_DATE('%Y-%m', DATE(event_time)) AS month, 
  COUNT(DISTINCT user_id) AS unique_buyers
FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
WHERE event_type = 'purchase'
GROUP BY month
ORDER BY month;

-- 2.2 Purchase Conversion Rate
-- Measures the percentage of monthly active users who completed a purchase.
WITH monthly_users AS (
  SELECT 
    FORMAT_DATE('%Y-%m', DATE(event_time)) AS month,
    COUNT(DISTINCT user_id) AS mau
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  GROUP BY month
),
monthly_buyers AS(
  SELECT
    FORMAT_DATE('%Y-%m', DATE(event_time)) AS month, 
    COUNT(DISTINCT user_id) AS unique_buyers
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  WHERE event_type = 'purchase'
  GROUP BY month
)

SELECT
  u.month,
  u.mau, 
  b.unique_buyers, 
  ROUND(100 * b.unique_buyers/u.mau, 2) AS purchase_conversion_rate
FROM monthly_users u
JOIN monthly_buyers b 
  ON u.month = b.month
ORDER BY u.month;

-- 2.3 Monthly Revenue
-- Calculates purchase revenue by month and month-over-month growth.
WITH monthly_revenue AS (
  SELECT 
    FORMAT_DATE('%Y-%m', DATE(event_time)) AS month,
    SUM(price) AS revenue
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  WHERE event_type = 'purchase'
  GROUP BY month
)

SELECT
  month,
  ROUND(revenue, 2) AS revenue,
  ROUND(
    100*(revenue - LAG(revenue) OVER (ORDER BY month))/
    LAG(revenue) OVER (ORDER BY month), 2) AS revenue_growth
  FROM monthly_revenue
  ORDER BY month;

-- 2.4 Average Revenue per User
-- Calculates monthly revenue generated per active user and its growth rate.
WITH monthly_users AS(
  SELECT
    FORMAT_DATE('%Y-%m', DATE(event_time)) AS month,
    COUNT(DISTINCT user_id) AS MAU
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  GROUP BY month
),

monthly_revenue AS(
  SELECT
   FORMAT_DATE('%Y-%m', DATE(event_time)) AS month,
    SUM(price) AS revenue
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  WHERE event_type = 'purchase'
  GROUP BY month
)

SELECT 
  u.month, 
  u.MAU, 
  ROUND(r.revenue, 2) AS revenue,
  ROUND(r.revenue/u.MAU, 2) AS ARPU,
  ROUND(
    100 * ((r.revenue/u.MAU) - LAG(r.revenue/u.MAU) OVER (ORDER BY u.month))/
    LAG(r.revenue/u.MAU) OVER (ORDER BY u.month), 2
  ) AS ARPU_growth_pct
FROM monthly_users u
JOIN monthly_revenue r
  ON u.month = r.month
ORDER BY u.month;

-- ============================================================
-- 3. PRODUCT AND BRAND PERFORMANCE
-- ============================================================

-- 3.1 Top Categories by Revenue
-- Ranks product categories based on purchase revenue.
SELECT
  COALESCE(category_code, 'unknown') AS category_code,
  COUNT(*) AS purchase_events,
  COUNT(DISTINCT user_id) AS unique_buyers,
  ROUND(SUM(price), 2) AS revenue
FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
WHERE event_type = 'purchase'
GROUP BY category_code
ORDER BY revenue DESC
LIMIT 10;

-- 3.2 Top Brands by Revenue
-- Ranks brands based on purchase revenue.
SELECT
  COALESCE(brand, 'unknown') AS brand,
  COUNT(*) AS purchase_events,
  COUNT(DISTINCT user_id) AS unique_buyers,
  ROUND(SUM(price), 2) AS revenue
FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
WHERE event_type = 'purchase'
GROUP BY brand
ORDER BY revenue DESC
LIMIT 10;

-- 3.3 Top Products by Purchase Volume
-- Identifies the most frequently purchased products.
SELECT
  product_id,
  COALESCE(category_code, 'unknown') AS category_code,
  COALESCE(brand, 'unknown') AS brand,
  COUNT(*) AS purchase_events,
  COUNT(DISTINCT user_id) AS unique_buyers,
  ROUND(SUM(price), 2) AS revenue
FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
WHERE event_type = 'purchase'
GROUP BY product_id, category_code, brand
ORDER BY purchase_events DESC
LIMIT 10;

-- ============================================================
-- 4. FUNNEL ANALYSIS
-- ============================================================

-- 4.1 Event Funnel
-- Measures the number of view, cart, and purchase events.
WITH funnel AS (
  SELECT
    COUNTIF(event_type = 'view') AS views,
    COUNTIF(event_type = 'cart') AS carts,
    COUNTIF(event_type = 'purchase') AS purchases
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
)

SELECT
  views,
  carts,
  purchases,
  ROUND(100 * carts / views, 2) AS view_to_cart_rate,
  ROUND(100 * purchases / carts, 2) AS cart_to_purchase_rate,
  ROUND(100 * purchases / views, 2) AS view_to_purchase_rate
FROM funnel;	

-- 4.2 User Funnel
-- Measures how many distinct users reached each funnel stage.
WITH user_funnel AS (
  SELECT
    COUNT(DISTINCT IF(event_type = 'view', user_id, NULL)) AS view_users,
    COUNT(DISTINCT IF(event_type = 'cart', user_id, NULL)) AS cart_users,
    COUNT(DISTINCT IF(event_type = 'purchase', user_id, NULL)) AS purchase_users
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
)

SELECT
  view_users,
  cart_users,
  purchase_users,
  ROUND(100 * cart_users / view_users, 2) AS view_to_cart_rate,
  ROUND(100 * purchase_users / cart_users, 2) AS cart_to_purchase_rate,
  ROUND(100 * purchase_users / view_users, 2) AS view_to_purchase_rate
FROM user_funnel;


-- ============================================================
-- 5. RETENTION AND CHURN
-- ============================================================

-- 5.1 Retained Users
-- Counts October users who returned in November.
WITH october_users AS(
  SELECT DISTINCT user_id
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  WHERE FORMAT_DATE('%Y-%m', DATE(event_time)) = '2019-10'
),

november_users AS (
  SELECT DISTINCT user_id
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  WHERE FORMAT_DATE('%Y-%m', DATE(event_time)) = '2019-11'
)

SELECT
  COUNT(*) AS retained_users
FROM october_users o 
JOIN november_users n
ON o.user_id = n.user_id;

-- 5.2 Retention Rate
-- Calculates the percentage of October users retained in November.
WITH october_users AS (
  SELECT DISTINCT user_id
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  WHERE FORMAT_DATE('%Y-%m', DATE(event_time)) = '2019-10'
),

november_users AS (
  SELECT DISTINCT user_id
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  WHERE FORMAT_DATE('%Y-%m', DATE(event_time)) = '2019-11'
),

retained AS (
  SELECT
      o.user_id
  FROM october_users o
  JOIN november_users n
      ON o.user_id = n.user_id
)

SELECT
    (SELECT COUNT(*) FROM october_users) AS october_users,
    (SELECT COUNT(*) FROM retained) AS retained_users,
    ROUND(
        100 * (SELECT COUNT(*) FROM retained)
        / (SELECT COUNT(*) FROM october_users),
        2
    ) AS retention_rate_pct;

-- 5.3 Churned Users
-- Counts October users who did not return in November.
WITH october_users AS (
  SELECT DISTINCT user_id
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  WHERE FORMAT_DATE('%Y-%m', DATE(event_time)) = '2019-10'
),

november_users AS (
  SELECT DISTINCT user_id
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  WHERE FORMAT_DATE('%Y-%m', DATE(event_time)) = '2019-11'
)

SELECT
    COUNT(*) AS churned_users
FROM october_users o
LEFT JOIN november_users n
ON o.user_id = n.user_id
WHERE n.user_id IS NULL;

-- 5.4 Churn Rate
-- Calculates the percentage of October users who churned.
WITH october_users AS (
  SELECT DISTINCT user_id
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  WHERE FORMAT_DATE('%Y-%m', DATE(event_time)) = '2019-10'
),

november_users AS (
  SELECT DISTINCT user_id
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  WHERE FORMAT_DATE('%Y-%m', DATE(event_time)) = '2019-11'
),

churned AS (
  SELECT o.user_id
  FROM october_users o
  LEFT JOIN november_users n
      ON o.user_id = n.user_id
  WHERE n.user_id IS NULL
)

SELECT
    (SELECT COUNT(*) FROM october_users) AS october_users,
    (SELECT COUNT(*) FROM churned) AS churned_users,
    ROUND(
        100 * (SELECT COUNT(*) FROM churned)
        / (SELECT COUNT(*) FROM october_users),
        2
    ) AS churn_rate_pct;

-- ============================================================
-- 6. COHORT ANALYSIS
-- ============================================================

-- 6.1 Cohort Activity
-- Groups users by first activity month and tracks activity over time.
WITH first_activity AS (
  SELECT
    user_id,
    DATE_TRUNC(MIN(DATE(event_time)), MONTH) AS cohort_month
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  GROUP BY user_id
),

user_activity AS (
  SELECT DISTINCT
    user_id,
    DATE_TRUNC(DATE(event_time), MONTH) AS activity_month
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
)

SELECT
  f.cohort_month,
  u.activity_month,
  COUNT(DISTINCT f.user_id) AS users
FROM first_activity f
JOIN user_activity u
  ON f.user_id = u.user_id
GROUP BY
  cohort_month,
  activity_month
ORDER BY
  cohort_month,
  activity_month;

-- 6.2 Cohort Retention Matrix
-- Calculates Month 0 and Month 1 retention percentages by cohort.
WITH first_activity AS (
  SELECT
    user_id,
    DATE_TRUNC(MIN(DATE(event_time)), MONTH) AS cohort_month
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  GROUP BY user_id
),

user_activity AS (
  SELECT DISTINCT
    user_id,
    DATE_TRUNC(DATE(event_time), MONTH) AS activity_month
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
),

cohort_data AS (
  SELECT
    f.cohort_month,
    u.activity_month,
    COUNT(DISTINCT f.user_id) AS users
  FROM first_activity f
  JOIN user_activity u ON f.user_id = u.user_id
  GROUP BY cohort_month, activity_month
),

cohort_size AS (
  SELECT
    cohort_month,
    users AS cohort_users
  FROM cohort_data
  WHERE activity_month = cohort_month
)

SELECT
  c.cohort_month,

  ROUND(
    100 * MAX(CASE WHEN activity_month = c.cohort_month THEN users END) / cohort_users,
    2
  ) AS month_0_pct,

  ROUND(
    100 * MAX(CASE WHEN activity_month = DATE_ADD(c.cohort_month, INTERVAL 1 MONTH) THEN users END) / cohort_users,
    2
  ) AS month_1_pct

FROM cohort_data c
JOIN cohort_size s ON c.cohort_month = s.cohort_month
GROUP BY c.cohort_month, cohort_users
ORDER BY c.cohort_month;
