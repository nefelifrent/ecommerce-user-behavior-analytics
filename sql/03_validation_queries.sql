-- ============================================================
-- E-COMMERCE USER BEHAVIOR ANALYTICS
-- Dashboard Validation Queries
-- Platform: Google BigQuery
-- Source table: ecommerce_analytics.events_partitioned
-- Dashboard reporting period: November 2019
--
-- These queries independently validate the metrics and
-- visualizations displayed in the Looker Studio dashboard.
-- ============================================================


-- ============================================================
-- 1. VERIFY DASHBOARD VIEWS
-- Confirms that the required dashboard views were created.
-- ============================================================

SELECT
  table_name,
  table_type
FROM
  `user-behavior-analytics-500015.ecommerce_analytics.INFORMATION_SCHEMA.TABLES`
WHERE table_name IN (
  'vw_dashboard_kpis',
  'vw_daily_activity',
  'vw_top_categories',
  'vw_top_brands',
  'vw_user_funnel',
  'vw_cohort_retention'
)
ORDER BY
  table_name;


-- ============================================================
-- 2. MONTHLY KPI VALIDATION
-- Independently calculates the dashboard KPIs for October
-- and November 2019 directly from the source table.
--
-- Expected November 2019 results:
-- MAU: 3,696,117
-- Unique buyers: 441,638
-- Purchase conversion rate: 11.95%
-- Revenue: $275,194,890.50
-- ARPU: $74.46
-- ============================================================

WITH monthly_kpis AS (
  SELECT
    DATE_TRUNC(DATE(event_time), MONTH) AS month,
    COUNT(DISTINCT user_id) AS mau,
    COUNT(
      DISTINCT IF(event_type = 'purchase', user_id, NULL)
    ) AS unique_buyers,
    SUM(
      IF(event_type = 'purchase', price, 0)
    ) AS revenue
  FROM
    `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  WHERE DATE(event_time) BETWEEN DATE '2019-10-01'
                             AND DATE '2019-11-30'
  GROUP BY
    month
)

SELECT
  month,
  mau,
  unique_buyers,

  ROUND(
    100 * SAFE_DIVIDE(unique_buyers, mau),
    2
  ) AS purchase_conversion_rate,

  ROUND(revenue, 2) AS revenue,

  ROUND(
    SAFE_DIVIDE(revenue, mau),
    2
  ) AS arpu

FROM monthly_kpis
ORDER BY
  month;


-- ============================================================
-- 3. MONTH-OVER-MONTH KPI CHANGE VALIDATION
-- Validates the KPI comparison values displayed in the
-- November scorecards.
--
-- Expected results:
-- MAU growth: 22.30%
-- Revenue growth: 19.67%
-- Conversion change: 0.46 percentage points
-- ARPU growth: -2.14%
-- ============================================================

WITH monthly_kpis AS (
  SELECT
    DATE_TRUNC(DATE(event_time), MONTH) AS month,
    COUNT(DISTINCT user_id) AS mau,
    COUNT(
      DISTINCT IF(event_type = 'purchase', user_id, NULL)
    ) AS unique_buyers,
    SUM(
      IF(event_type = 'purchase', price, 0)
    ) AS revenue
  FROM
    `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  WHERE DATE(event_time) BETWEEN DATE '2019-10-01'
                             AND DATE '2019-11-30'
  GROUP BY
    month
),

calculated_kpis AS (
  SELECT
    month,
    mau,
    ROUND(
      100 * SAFE_DIVIDE(unique_buyers, mau),
      2
    ) AS conversion_rate,
    revenue,
    SAFE_DIVIDE(revenue, mau) AS arpu
  FROM monthly_kpis
),

kpis_with_previous AS (
  SELECT
    *,
    LAG(mau) OVER (ORDER BY month) AS previous_mau,
    LAG(revenue) OVER (ORDER BY month) AS previous_revenue,
    LAG(conversion_rate) OVER (ORDER BY month)
      AS previous_conversion_rate,
    LAG(arpu) OVER (ORDER BY month) AS previous_arpu
  FROM calculated_kpis
)

SELECT
  month,

  ROUND(
    100 * SAFE_DIVIDE(
      mau - previous_mau,
      previous_mau
    ),
    2
  ) AS mau_growth_pct,

  ROUND(
    100 * SAFE_DIVIDE(
      revenue - previous_revenue,
      previous_revenue
    ),
    2
  ) AS revenue_growth_pct,

  ROUND(
    conversion_rate - previous_conversion_rate,
    2
  ) AS conversion_change_pp,

  ROUND(
    100 * SAFE_DIVIDE(
      arpu - previous_arpu,
      previous_arpu
    ),
    2
  ) AS arpu_growth_pct

FROM kpis_with_previous
WHERE month = DATE '2019-11-01';


-- ============================================================
-- 4. RETENTION VALIDATION
-- Measures the percentage of users active in October 2019
-- who returned in November 2019.
--
-- Expected results:
-- October users: 3,022,290
-- Retained users: 1,401,758
-- Retention rate: 46.38%
-- ============================================================

WITH october_users AS (
  SELECT DISTINCT
    user_id
  FROM
    `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  WHERE DATE(event_time) BETWEEN DATE '2019-10-01'
                             AND DATE '2019-10-31'
),

november_users AS (
  SELECT DISTINCT
    user_id
  FROM
    `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  WHERE DATE(event_time) BETWEEN DATE '2019-11-01'
                             AND DATE '2019-11-30'
),

retained_users AS (
  SELECT
    o.user_id
  FROM october_users AS o
  INNER JOIN november_users AS n
    ON o.user_id = n.user_id
)

SELECT
  (SELECT COUNT(*) FROM october_users) AS october_users,
  (SELECT COUNT(*) FROM retained_users) AS retained_users,

  ROUND(
    100 * SAFE_DIVIDE(
      (SELECT COUNT(*) FROM retained_users),
      (SELECT COUNT(*) FROM october_users)
    ),
    2
  ) AS retention_rate_pct;


-- ============================================================
-- 5. DAILY ACTIVE USERS VALIDATION
-- Validates the daily user trend displayed in the dashboard.
--
-- Expected peak:
-- November 17, 2019: 487,501 active users
-- ============================================================

SELECT
  DATE(event_time) AS event_date,
  COUNT(DISTINCT user_id) AS dau
FROM
  `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
WHERE DATE(event_time) BETWEEN DATE '2019-11-01'
                           AND DATE '2019-11-30'
GROUP BY
  event_date
ORDER BY
  dau DESC;


-- ============================================================
-- 6. TOP CATEGORIES VALIDATION
-- Validates the November 2019 category ranking by revenue.
-- Null category values are grouped under "unknown".
-- ============================================================

SELECT
  COALESCE(category_code, 'unknown') AS category_code,
  COUNT(*) AS purchase_events,
  COUNT(DISTINCT user_id) AS unique_buyers,
  ROUND(SUM(price), 2) AS revenue
FROM
  `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
WHERE event_type = 'purchase'
  AND DATE(event_time) BETWEEN DATE '2019-11-01'
                           AND DATE '2019-11-30'
GROUP BY
  category_code
ORDER BY
  revenue DESC
LIMIT 10;


-- ============================================================
-- 7. TOP BRANDS VALIDATION
-- Validates the November 2019 brand ranking by revenue.
--
-- Expected leading results:
-- Apple: $127,512,524.88
-- Samsung: $54,869,880.87
-- Xiaomi: $11,259,865.96
-- Unknown: $11,025,718.79
-- LG: $5,239,018.76
-- ============================================================

SELECT
  COALESCE(brand, 'unknown') AS brand,
  COUNT(*) AS purchase_events,
  COUNT(DISTINCT user_id) AS unique_buyers,
  ROUND(SUM(price), 2) AS revenue
FROM
  `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
WHERE event_type = 'purchase'
  AND DATE(event_time) BETWEEN DATE '2019-11-01'
                           AND DATE '2019-11-30'
GROUP BY
  brand
ORDER BY
  revenue DESC
LIMIT 10;


-- ============================================================
-- 8. USER FUNNEL VALIDATION
-- Validates the number of distinct users reaching each funnel
-- stage during November 2019.
--
-- Expected results:
-- Product View users: 3,695,598
-- Add to Cart users: 826,323
-- Purchase users: 441,638
-- View-to-Cart conversion: 22.36%
-- Cart-to-Purchase conversion: 53.45%
-- View-to-Purchase conversion: 11.95%
--
-- The query does not enforce chronological event order.
-- ============================================================

WITH user_funnel AS (
  SELECT
    COUNT(
      DISTINCT IF(event_type = 'view', user_id, NULL)
    ) AS view_users,

    COUNT(
      DISTINCT IF(event_type = 'cart', user_id, NULL)
    ) AS cart_users,

    COUNT(
      DISTINCT IF(event_type = 'purchase', user_id, NULL)
    ) AS purchase_users

  FROM
    `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`

  WHERE DATE(event_time) BETWEEN DATE '2019-11-01'
                             AND DATE '2019-11-30'
)

SELECT
  view_users,
  cart_users,
  purchase_users,

  ROUND(
    100 * SAFE_DIVIDE(cart_users, view_users),
    2
  ) AS view_to_cart_rate,

  ROUND(
    100 * SAFE_DIVIDE(purchase_users, cart_users),
    2
  ) AS cart_to_purchase_rate,

  ROUND(
    100 * SAFE_DIVIDE(purchase_users, view_users),
    2
  ) AS view_to_purchase_rate

FROM user_funnel;


-- ============================================================
-- 9. COHORT RETENTION VALIDATION
-- Validates the cohort counts used in the retention table.
--
-- Expected results:
-- October cohort in October: 3,022,290 users
-- October cohort in November: 1,401,758 users
-- November cohort in November: 2,294,359 users
-- ============================================================

WITH first_activity AS (
  SELECT
    user_id,
    DATE_TRUNC(
      MIN(DATE(event_time)),
      MONTH
    ) AS cohort_month
  FROM
    `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  GROUP BY
    user_id
),

user_activity AS (
  SELECT DISTINCT
    user_id,
    DATE_TRUNC(
      DATE(event_time),
      MONTH
    ) AS activity_month
  FROM
    `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
),

cohort_data AS (
  SELECT
    f.cohort_month,
    u.activity_month,
    COUNT(DISTINCT f.user_id) AS users
  FROM first_activity AS f
  INNER JOIN user_activity AS u
    ON f.user_id = u.user_id
  GROUP BY
    f.cohort_month,
    u.activity_month
)

SELECT
  cohort_month,
  activity_month,
  users
FROM cohort_data
ORDER BY
  cohort_month,
  activity_month;


-- ============================================================
-- 10. NOVEMBER USER COMPOSITION VALIDATION
-- Confirms that November MAU consists of retained October users
-- plus users whose first activity occurred in November.
--
-- Expected calculation:
-- 1,401,758 returning users
-- + 2,294,359 new November users
-- = 3,696,117 November active users
-- ============================================================

WITH first_activity AS (
  SELECT
    user_id,
    DATE_TRUNC(
      MIN(DATE(event_time)),
      MONTH
    ) AS cohort_month
  FROM
    `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  GROUP BY
    user_id
),

november_users AS (
  SELECT DISTINCT
    user_id
  FROM
    `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  WHERE DATE(event_time) BETWEEN DATE '2019-11-01'
                             AND DATE '2019-11-30'
)

SELECT
  COUNTIF(
    f.cohort_month = DATE '2019-10-01'
  ) AS returning_october_users,

  COUNTIF(
    f.cohort_month = DATE '2019-11-01'
  ) AS new_november_users,

  COUNT(*) AS november_mau

FROM november_users AS n
INNER JOIN first_activity AS f
  ON n.user_id = f.user_id;