-- Monthly acquisition channel performance
-- Classifies website sessions by acquisition channel and calculates monthly
-- sessions, orders, conversion rate, revenue, AOV, and revenue per session.
-- Note: missing UTM/referrer values are stored as the literal string 'NULL'
-- in the source dataset.

WITH session_channels AS (
SELECT
	ws.website_session_id,
	o.order_id,
	o.price_usd,
	DATE_TRUNC('month', ws.created_at::timestamp) AS month_start,
	--classify each session into a single acquisition channel
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
	ws.website_session_id = o.website_session_id)
--aggregate performance by month and acquisition channel
SELECT  				
	month_start::DATE AS month_start,
	TO_CHAR(month_start, 'Month YYYY') AS month,
	channel,
	COUNT(order_id) AS orders,
	COUNT(*) AS sessions,
	ROUND(COUNT(order_id) * 100.0 / COUNT(*), 2) AS conversion_rate,
	ROUND(SUM(price_usd::NUMERIC), 2) AS revenue,
	ROUND(SUM(price_usd::NUMERIC) / NULLIF(COUNT(order_id), 0), 2) AS aov,
	ROUND(SUM(price_usd::NUMERIC) / COUNT(*), 2) AS revenue_per_session
FROM
	session_channels
GROUP BY
	channel,
	month_start
ORDER BY
	channel,
	month_start;