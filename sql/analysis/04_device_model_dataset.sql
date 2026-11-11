--Session-level dataset for device conversion modelling
--Prepares one row per website session with conversion outcome, device type,
--acquisition channel, repeat-session status, and order information for Python analysis.
-- Note: missing UTM/referrer values are stored as the literal string 'NULL' in the source dataset.

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
	--binary purchase outcome used as the dependent variable in the GEE model
	CASE
		WHEN o.order_id IS NOT NULL THEN 1
		ELSE 0
	END AS converted,	
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
		ws.website_session_id = o.website_session_id;
