-- ============================================================
-- E-COMMERCE USER BEHAVIOR ANALYTICS
-- Dashboard Views
-- Platform: Google BigQuery
-- Source table: ecommerce_analytics.events_partitioned
--
-- This script creates the views used as data sources
-- for the Looker Studio dashboard.
-- ============================================================


-- ============================================================
-- 1. DASHBOARD KPI VIEW
-- ============================================================

-- Creates monthly KPI values for:
-- - Monthly Active Users
-- - Unique Buyers
-- - Purchase Conversion Rate
-- - Revenue
-- - Average Revenue per User
-- - Retention Rate
-- - Month-over-month KPI changes
--
-- The is_latest_month field is used in Looker Studio
-- to display only the most recent month in KPI scorecards.

CREATE OR REPLACE VIEW
`user-behavior-analytics-500015.ecommerce_analytics.vw_dashboard_kpis` AS

WITH monthly_data AS (
  SELECT
    DATE_TRUNC(DATE(event_time), MONTH) AS month,
    COUNT(DISTINCT user_id) AS mau,
    COUNT(DISTINCT IF(event_type = 'purchase', user_id, NULL)) AS unique_buyers,
    SUM(IF(event_type = 'purchase', price, 0)) AS revenue
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  GROUP BY month
),

user_months AS (
  SELECT DISTINCT
    user_id,
    DATE_TRUNC(DATE(event_time), MONTH) AS activity_month
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
),

monthly_retention AS (
  SELECT
    DATE_ADD(current_month.activity_month, INTERVAL 1 MONTH) AS month,
    ROUND(
      100 * SAFE_DIVIDE(
        COUNT(DISTINCT next_month.user_id),
        COUNT(DISTINCT current_month.user_id)
      ),
      2
    ) AS retention_rate
  FROM user_months current_month
  LEFT JOIN user_months next_month
    ON current_month.user_id = next_month.user_id
   AND next_month.activity_month =
       DATE_ADD(current_month.activity_month, INTERVAL 1 MONTH)
  GROUP BY month
),

kpis AS (
  SELECT
    m.month,
    m.mau,
    m.unique_buyers,
    ROUND(
      100 * SAFE_DIVIDE(m.unique_buyers, m.mau),
      2
    ) AS purchase_conversion_rate,
    ROUND(m.revenue, 2) AS revenue,
    ROUND(SAFE_DIVIDE(m.revenue, m.mau), 2) AS arpu,
    r.retention_rate
  FROM monthly_data m
  LEFT JOIN monthly_retention r USING (month)
),

kpis_with_previous AS (
  SELECT
    *,
    LAG(mau) OVER (ORDER BY month) AS previous_mau,
    LAG(revenue) OVER (ORDER BY month) AS previous_revenue,
    LAG(purchase_conversion_rate) OVER (ORDER BY month)
      AS previous_conversion_rate,
    LAG(arpu) OVER (ORDER BY month) AS previous_arpu
  FROM kpis
)

SELECT
  month,
  mau,
  unique_buyers,
  purchase_conversion_rate,
  revenue,
  arpu,
  retention_rate,

  ROUND(
    100 * SAFE_DIVIDE(mau - previous_mau, previous_mau),
    2
  ) AS mau_growth_pct,

  ROUND(
    100 * SAFE_DIVIDE(revenue - previous_revenue, previous_revenue),
    2
  ) AS revenue_growth_pct,

  ROUND(
    purchase_conversion_rate - previous_conversion_rate,
    2
  ) AS conversion_change_pp,

  ROUND(
    100 * SAFE_DIVIDE(arpu - previous_arpu, previous_arpu),
    2
  ) AS arpu_growth_pct,

  month = MAX(month) OVER () AS is_latest_month

FROM kpis_with_previous;


-- ============================================================
-- 2. DAILY ACTIVITY VIEW
-- ============================================================

-- Provides daily active users and total event volume
-- for the Daily Active Users trend chart.

CREATE OR REPLACE VIEW
`user-behavior-analytics-500015.ecommerce_analytics.vw_daily_activity` AS

SELECT
  DATE(event_time) AS event_date,
  COUNT(*) AS total_events,
  COUNT(DISTINCT user_id) AS dau
FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
GROUP BY event_date;


-- ============================================================
-- 3. TOP CATEGORIES VIEW
-- ============================================================

-- Aggregates purchase performance by product category.
-- Null category values are grouped under "Unknown".
-- The raw category code is converted into a shorter,
-- dashboard-friendly category name.

CREATE OR REPLACE VIEW
`user-behavior-analytics-500015.ecommerce_analytics.vw_top_categories` AS

WITH category_revenue AS (
  SELECT
    COALESCE(category_code, 'unknown') AS category_code,
    COUNT(*) AS purchase_events,
    COUNT(DISTINCT user_id) AS unique_buyers,
    SUM(price) AS revenue
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  WHERE event_type = 'purchase'
  GROUP BY category_code
)

SELECT
  category_code,

  CASE
    WHEN category_code = 'electronics.smartphone' THEN 'Smartphone'
    WHEN category_code = 'electronics.audio.headphone' THEN 'Headphones'
    WHEN category_code = 'electronics.audio.subwoofer' THEN 'Subwoofer'
    WHEN category_code = 'electronics.video.tv' THEN 'TV'
    WHEN category_code = 'electronics.tablet' THEN 'Tablet'
    WHEN category_code = 'computers.notebook' THEN 'Notebook'
    WHEN category_code = 'computers.desktop' THEN 'Desktop'
    WHEN category_code = 'appliances.kitchen.refrigerators' THEN 'Refrigerators'
    WHEN category_code = 'appliances.kitchen.washer' THEN 'Washing Machines'
    WHEN category_code = 'unknown' THEN 'Unknown'
    ELSE INITCAP(REPLACE(SPLIT(category_code, '.')[SAFE_OFFSET(ARRAY_LENGTH(SPLIT(category_code, '.')) - 1)], '_', ' '))
  END AS category_name,

  purchase_events,
  unique_buyers,
  ROUND(revenue, 2) AS revenue,
  ROUND(
    100 * SAFE_DIVIDE(revenue, SUM(revenue) OVER ()),
    2
  ) AS revenue_share_pct

FROM category_revenue;


-- ============================================================
-- 4. TOP BRANDS VIEW
-- ============================================================

-- Aggregates purchase performance by brand.
-- Null brand values are grouped under "unknown".

CREATE OR REPLACE VIEW
`user-behavior-analytics-500015.ecommerce_analytics.vw_top_brands` AS

WITH brand_revenue AS (
  SELECT
    COALESCE(brand, 'unknown') AS brand,
    COUNT(*) AS purchase_events,
    COUNT(DISTINCT user_id) AS unique_buyers,
    SUM(price) AS revenue
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  WHERE event_type = 'purchase'
  GROUP BY brand
)

SELECT
  brand,
  purchase_events,
  unique_buyers,
  ROUND(revenue, 2) AS revenue,
  ROUND(
    100 * SAFE_DIVIDE(revenue, SUM(revenue) OVER ()),
    2
  ) AS revenue_share_pct
FROM brand_revenue;


-- ============================================================
-- 5. USER FUNNEL VIEW
-- ============================================================

-- Counts distinct users at each funnel stage:
-- Product View, Add to Cart, and Purchase.
--
-- Conversion percentages are calculated relative
-- to the Product View stage.
--
-- This funnel does not enforce chronological event order.

CREATE OR REPLACE VIEW
`user-behavior-analytics-500015.ecommerce_analytics.vw_user_funnel` AS

WITH funnel_counts AS (
  SELECT
    COUNT(DISTINCT IF(event_type = 'view', user_id, NULL))
      AS view_users,
    COUNT(DISTINCT IF(event_type = 'cart', user_id, NULL))
      AS cart_users,
    COUNT(DISTINCT IF(event_type = 'purchase', user_id, NULL))
      AS purchase_users
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
)

SELECT
  1 AS stage_order,
  'Product View' AS stage,
  view_users AS users,
  100.00 AS conversion_from_view_pct
FROM funnel_counts

UNION ALL

SELECT
  2,
  'Add to Cart',
  cart_users,
  ROUND(100 * SAFE_DIVIDE(cart_users, view_users), 2)
FROM funnel_counts

UNION ALL

SELECT
  3,
  'Purchase',
  purchase_users,
  ROUND(100 * SAFE_DIVIDE(purchase_users, view_users), 2)
FROM funnel_counts;

-- ============================================================
-- 6. COHORT RETENTION VIEW
-- ============================================================

-- Assigns users to cohorts based on their first activity month.
-- Month 0 represents activity during the acquisition month.
-- Month 1 represents activity during the following month.

CREATE OR REPLACE VIEW
`user-behavior-analytics-500015.ecommerce_analytics.vw_cohort_retention` AS

WITH first_activity AS (
  SELECT
    user_id,
    DATE_TRUNC(
      MIN(DATE(event_time)),
      MONTH
    ) AS cohort_month
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
  GROUP BY user_id
),

user_activity AS (
  SELECT DISTINCT
    user_id,
    DATE_TRUNC(
      DATE(event_time),
      MONTH
    ) AS activity_month
  FROM `user-behavior-analytics-500015.ecommerce_analytics.events_partitioned`
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
),

cohort_sizes AS (
  SELECT
    cohort_month,
    users AS cohort_users
  FROM cohort_data
  WHERE activity_month = cohort_month
)

SELECT
  c.cohort_month,
  s.cohort_users,

  ROUND(
    100 * SAFE_DIVIDE(
      MAX(
        CASE
          WHEN c.activity_month = c.cohort_month
            THEN c.users
        END
      ),
      s.cohort_users
    ),
    2
  ) AS month_0_pct,

  ROUND(
    100 * SAFE_DIVIDE(
      MAX(
        CASE
          WHEN c.activity_month =
               DATE_ADD(
                 c.cohort_month,
                 INTERVAL 1 MONTH
               )
            THEN c.users
        END
      ),
      s.cohort_users
    ),
    2
  ) AS month_1_pct

FROM cohort_data AS c
INNER JOIN cohort_sizes AS s
  ON c.cohort_month = s.cohort_month
GROUP BY
  c.cohort_month,
  s.cohort_users;