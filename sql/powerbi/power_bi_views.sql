-- Power BI data layer
-- Creates the analytics views used by the Power BI dashboard.

CREATE SCHEMA IF NOT EXISTS analytics;
-- Monthly performance view
CREATE OR REPLACE
VIEW analytics.monthly_trends AS
WITH monthly_sessions AS (
SELECT
	DATE_TRUNC('month', created_at::TIMESTAMP) AS month_start,
	COUNT(*) AS sessions
FROM
	website_sessions
GROUP BY
	month_start
),
monthly_orders AS (
SELECT
	DATE_TRUNC('month', created_at::TIMESTAMP) AS month_start,
	COUNT(*) AS orders,
	SUM(price_usd) AS revenue,
	AVG(price_usd) AS aov
FROM
	orders
GROUP BY
	month_start
),
monthly_data AS (
SELECT
	ms.sessions,
	mo.orders,
	ms.month_start,
	mo.orders * 100.0 / ms.sessions AS conversion_rate,
	mo.revenue,
	mo.aov,
	mo.revenue / ms.sessions AS rev_per_session
FROM
	monthly_sessions ms
JOIN monthly_orders mo
        ON
	ms.month_start = mo.month_start
),
month_lag AS (
SELECT
	monthly_data.*,
	LAG(sessions) OVER (
ORDER BY
	month_start
        ) AS previous_sessions,
	LAG(revenue) OVER (
ORDER BY
	month_start
        ) AS previous_revenue,
	LAG(conversion_rate) OVER (
ORDER BY
	month_start
        ) AS previous_conversion_rate
FROM
	monthly_data
)
SELECT
	month_start::DATE AS month_start,
	TO_CHAR(month_start, 'Mon YYYY') AS MONTH,
	orders,
	sessions,
	ROUND(conversion_rate, 2) AS conversion_rate,
	ROUND(revenue::NUMERIC, 2) AS revenue,
	ROUND(aov::NUMERIC, 2) AS aov,
	ROUND(rev_per_session::NUMERIC, 2) AS revenue_per_session,
	CASE
		WHEN month_start::DATE = DATE '2015-03-01' THEN NULL
		ELSE ROUND(
            (sessions - previous_sessions) * 100.0 / previous_sessions,
            2
        )
	END AS mom_growth_sessions,
	CASE
		WHEN month_start::DATE = DATE '2015-03-01' THEN NULL
		ELSE ROUND(
            ((revenue - previous_revenue) * 100.0 / previous_revenue)::NUMERIC,
            2
        )
	END AS mom_growth_revenue,
	CASE
		WHEN month_start::DATE = DATE '2015-03-01' THEN NULL
		ELSE ROUND(
            conversion_rate - previous_conversion_rate,
            2
        )
	END AS conversion_change_pp,
	month_start::DATE IN (
        DATE '2012-03-01',
        DATE '2015-03-01'
    ) AS is_partial_month
FROM
	month_lag;

-- Monthly acquisition channel performance view
CREATE OR REPLACE
VIEW analytics.channel_trends AS
WITH session_channels AS (
SELECT
	ws.website_session_id,
	o.order_id,
	o.price_usd,
	DATE_TRUNC('month', ws.created_at::TIMESTAMP) AS month_start,
	CASE
		WHEN ws.utm_source IN ('gsearch', 'bsearch')
                THEN 'Paid Search'
		WHEN ws.utm_source = 'socialbook'
                THEN 'Paid Social'
		WHEN ws.utm_source = 'NULL'
		AND ws.http_referer IN (
                     'https://www.gsearch.com',
                     'https://www.bsearch.com'
                 )
                THEN 'Organic Search'
		WHEN ws.utm_source = 'NULL'
		AND ws.utm_campaign = 'NULL'
		AND ws.http_referer = 'NULL'
                THEN 'Direct'
		ELSE 'Other'
	END AS channel
FROM
	website_sessions ws
LEFT JOIN orders o
        ON
	ws.website_session_id = o.website_session_id
)
SELECT
	month_start::DATE AS month_start,
	TO_CHAR(month_start, 'Month YYYY') AS MONTH,
	channel,
	COUNT(order_id) AS orders,
	COUNT(*) AS sessions,
	ROUND(
        COUNT(order_id) * 100.0 / COUNT(*),
        2
    ) AS conversion_rate,
	ROUND(
        SUM(price_usd::NUMERIC),
        2
    ) AS revenue,
	ROUND(
        SUM(price_usd::NUMERIC) / NULLIF(COUNT(order_id), 0),
        2
    ) AS aov,
	ROUND(
        SUM(price_usd::NUMERIC) / COUNT(*),
        2
    ) AS revenue_per_session
FROM
	session_channels
GROUP BY
	channel,
	month_start;

-- Funnel performance by device view
CREATE OR REPLACE
VIEW analytics.funnel_by_device AS
WITH funnel_timestamps AS (
SELECT
	website_session_id,
	MIN(
            CASE
                WHEN pageview_url IN (
                    '/home',
                    '/lander-1',
                    '/lander-2',
                    '/lander-3',
                    '/lander-4',
                    '/lander-5'
                )
                THEN created_at::TIMESTAMP
            END
        ) AS landing_at,
	MIN(
            CASE
                WHEN pageview_url = '/products'
                THEN created_at::TIMESTAMP
            END
        ) AS products_at,
	MIN(
            CASE
                WHEN pageview_url IN (
                    '/the-original-mr-fuzzy',
                    '/the-forever-love-bear',
                    '/the-birthday-sugar-panda',
                    '/the-hudson-river-mini-bear'
                )
                THEN created_at::TIMESTAMP
            END
        ) AS product_detail_at,
	MIN(
            CASE
                WHEN pageview_url = '/cart'
                THEN created_at::TIMESTAMP
            END
        ) AS cart_at,
	MIN(
            CASE
                WHEN pageview_url = '/shipping'
                THEN created_at::TIMESTAMP
            END
        ) AS shipping_at,
	MIN(
            CASE
                WHEN pageview_url IN ('/billing', '/billing-2')
                THEN created_at::TIMESTAMP
            END
        ) AS billing_at,
	MIN(
            CASE
                WHEN pageview_url = '/thank-you-for-your-order'
                THEN created_at::TIMESTAMP
            END
        ) AS purchase_at
FROM
	website_pageviews
GROUP BY
	website_session_id
),
funnel_device AS (
SELECT
	f.*,
	ws.device_type
FROM
	funnel_timestamps f
JOIN website_sessions ws
        ON
	f.website_session_id = ws.website_session_id
),
funnel_counts AS (
SELECT
	device_type,
	COUNT(*) FILTER (
WHERE
	landing_at IS NOT NULL
        ) AS landing_sessions,
	COUNT(*) FILTER (
WHERE
	landing_at IS NOT NULL
	AND products_at > landing_at
        ) AS products_sessions,
	COUNT(*) FILTER (
WHERE
	landing_at IS NOT NULL
	AND products_at > landing_at
	AND product_detail_at > products_at
        ) AS product_detail_sessions,
	COUNT(*) FILTER (
WHERE
	landing_at IS NOT NULL
	AND products_at > landing_at
	AND product_detail_at > products_at
	AND cart_at > product_detail_at
        ) AS cart_sessions,
	COUNT(*) FILTER (
WHERE
	landing_at IS NOT NULL
	AND products_at > landing_at
	AND product_detail_at > products_at
	AND cart_at > product_detail_at
	AND shipping_at > cart_at
        ) AS shipping_sessions,
	COUNT(*) FILTER (
WHERE
	landing_at IS NOT NULL
	AND products_at > landing_at
	AND product_detail_at > products_at
	AND cart_at > product_detail_at
	AND shipping_at > cart_at
	AND billing_at > shipping_at
        ) AS billing_sessions,
	COUNT(*) FILTER (
WHERE
	landing_at IS NOT NULL
	AND products_at > landing_at
	AND product_detail_at > products_at
	AND cart_at > product_detail_at
	AND shipping_at > cart_at
	AND billing_at > shipping_at
	AND purchase_at > billing_at
        ) AS purchase_sessions
FROM
	funnel_device
GROUP BY
	device_type
)
SELECT
	device_type,
	landing_sessions,
	products_sessions,
	product_detail_sessions,
	cart_sessions,
	shipping_sessions,
	billing_sessions,
	purchase_sessions,
	ROUND(products_sessions * 100.0 / landing_sessions, 2)
        AS landing_to_products,
	ROUND(product_detail_sessions * 100.0 / products_sessions, 2)
        AS products_to_detail,
	ROUND(cart_sessions * 100.0 / product_detail_sessions, 2)
        AS detail_to_cart,
	ROUND(shipping_sessions * 100.0 / cart_sessions, 2)
        AS cart_to_shipping,
	ROUND(billing_sessions * 100.0 / shipping_sessions, 2)
        AS shipping_to_billing,
	ROUND(purchase_sessions * 100.0 / billing_sessions, 2)
        AS billing_to_purchase,
	ROUND(
        (landing_sessions - products_sessions) * 100.0
        / landing_sessions,
        2
    ) AS landing_to_products_dropoff_pct,
	ROUND(
        (products_sessions - product_detail_sessions) * 100.0
        / products_sessions,
        2
    ) AS products_to_detail_dropoff_pct,
	ROUND(
        (product_detail_sessions - cart_sessions) * 100.0
        / product_detail_sessions,
        2
    ) AS detail_to_cart_dropoff_pct,
	ROUND(
        (cart_sessions - shipping_sessions) * 100.0
        / cart_sessions,
        2
    ) AS cart_to_shipping_dropoff_pct,
	ROUND(
        (shipping_sessions - billing_sessions) * 100.0
        / shipping_sessions,
        2
    ) AS shipping_to_billing_dropoff_pct,
	ROUND(
        (billing_sessions - purchase_sessions) * 100.0
        / billing_sessions,
        2
    ) AS billing_to_purchase_dropoff_pct,
	ROUND(
        purchase_sessions * 100.0 / landing_sessions,
        2
    ) AS overall_conversion_rate
FROM
	funnel_counts;

-- Long-format funnel stage counts for Power BI
CREATE OR REPLACE
VIEW analytics.funnel_stages AS
SELECT
	INITCAP(device_type)::VARCHAR(50) AS device_type,
	'Landing' AS stage,
	1 AS stage_order,
	landing_sessions AS sessions
FROM
	analytics.funnel_by_device
UNION ALL
SELECT
	INITCAP(device_type)::VARCHAR(50),
	'Products',
	2,
	products_sessions
FROM
	analytics.funnel_by_device
UNION ALL
SELECT
	INITCAP(device_type)::VARCHAR(50),
	'Product Detail',
	3,
	product_detail_sessions
FROM
	analytics.funnel_by_device
UNION ALL
SELECT
	INITCAP(device_type)::VARCHAR(50),
	'Cart',
	4,
	cart_sessions
FROM
	analytics.funnel_by_device
UNION ALL
SELECT
	INITCAP(device_type)::VARCHAR(50),
	'Shipping',
	5,
	shipping_sessions
FROM
	analytics.funnel_by_device
UNION ALL
SELECT
	INITCAP(device_type)::VARCHAR(50),
	'Billing',
	6,
	billing_sessions
FROM
	analytics.funnel_by_device
UNION ALL
SELECT
	INITCAP(device_type)::VARCHAR(50),
	'Purchase',
	7,
	purchase_sessions
FROM
	analytics.funnel_by_device;

-- Session-level dataset used for device conversion modelling in Python
CREATE OR REPLACE
VIEW analytics.gee AS
SELECT
	ws.website_session_id,
	ws.user_id,
	ws.device_type,
	ws.created_at,
	ws.utm_source,
	ws.utm_campaign,
	ws.utm_content,
	ws.http_referer,
	o.order_id,
	o.price_usd,
	ws.is_repeat_session,
	CASE
		WHEN o.order_id IS NOT NULL THEN 1
		ELSE 0
	END AS converted,
	CASE
		WHEN ws.utm_source IN ('gsearch', 'bsearch')
            THEN 'Paid Search'
		WHEN ws.utm_source = 'socialbook'
            THEN 'Paid Social'
		WHEN ws.utm_source = 'NULL'
		AND ws.http_referer IN (
                 'https://www.gsearch.com',
                 'https://www.bsearch.com'
             )
            THEN 'Organic Search'
		WHEN ws.utm_source = 'NULL'
		AND ws.utm_campaign = 'NULL'
		AND ws.http_referer = 'NULL'
            THEN 'Direct'
		ELSE 'Other'
	END AS channel
FROM
	website_sessions ws
LEFT JOIN orders o
    ON
	ws.website_session_id = o.website_session_id;

-- Landing-page A/B test summary for Power BI
CREATE OR REPLACE
VIEW analytics.ab_test AS
WITH eligible_sessions AS (
SELECT
	website_session_id,
	created_at::TIMESTAMP
FROM
	website_sessions
WHERE
	created_at::TIMESTAMP >= '2012-06-19'
	AND created_at::TIMESTAMP < '2012-07-30'
),
first_pageview AS (
SELECT
	wp.website_session_id,
	MIN(wp.website_pageview_id) AS first_pageview_id
FROM
	website_pageviews wp
JOIN eligible_sessions es
        ON
	wp.website_session_id = es.website_session_id
GROUP BY
	wp.website_session_id
),
landing_pages AS (
SELECT
	wp.website_session_id,
	wp.pageview_url AS landing_page
FROM
	website_pageviews wp
JOIN first_pageview fp
        ON
	wp.website_pageview_id = fp.first_pageview_id
WHERE
	wp.pageview_url IN ('/home', '/lander-1')
),
pageview_counts AS (
SELECT
	COUNT(*) AS pageview_count,
	lp.website_session_id,
	lp.landing_page
FROM
	landing_pages lp
JOIN website_pageviews wp
        ON
	lp.website_session_id = wp.website_session_id
GROUP BY
	lp.website_session_id,
	lp.landing_page
)
SELECT
	landing_page,
	COUNT(*) AS total_sessions,
	SUM(
        CASE
            WHEN pageview_count = 1 THEN 1
            ELSE 0
        END
    ) AS bounces,
	ROUND(
        AVG(
            CASE
                WHEN pageview_count = 1 THEN 1
                ELSE 0
            END
        ) * 100,
        2
    ) AS bounce_rate
FROM
	pageview_counts
GROUP BY
	landing_page;