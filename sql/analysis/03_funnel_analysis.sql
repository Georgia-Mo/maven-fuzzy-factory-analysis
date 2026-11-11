--Funnel analysis by device
--Tracks sessions through the main purchase funnel in chronological order
--and calculates stage conversion, drop-off, and overall conversion rates.

--identify the first timestamp at which each session reached every funnel stage
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
--add device type to each session-level funnel record
funnel_device AS (
SELECT
	f.*,
	ws.device_type
FROM
	funnel_timestamps f
JOIN website_sessions ws ON
	f.website_session_id = ws.website_session_id),
--count sessions that progressed through each stage in the required order
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
--calculate stage conversion rates, drop-off rates, and overall conversion by device
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
	ROUND(purchase_sessions * 100.0 / landing_sessions, 2) AS overall_conversion_rate
FROM
	funnel_counts;