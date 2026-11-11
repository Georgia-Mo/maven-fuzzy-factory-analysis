--Landing-page A/B test
--Reviews daily traffic to define the analysis window,
--then compares bounce rates between /home and /lander-1.


--Step 1: Inspect daily landing-page traffic to define the test window
WITH first_pageview AS (
    SELECT
        website_session_id,
        MIN(website_pageview_id) AS first_pageview_id
    FROM website_pageviews
    GROUP BY website_session_id
),
landing_pages AS (
    SELECT
        fp.website_session_id,
        wp.pageview_url AS landing_page
    FROM first_pageview fp
    JOIN website_pageviews wp
        ON fp.first_pageview_id = wp.website_pageview_id
)
SELECT
    DATE(ws.created_at::TIMESTAMP) AS date,
    lp.landing_page,
    COUNT(*) AS sessions
FROM landing_pages lp
JOIN website_sessions ws
    ON lp.website_session_id = ws.website_session_id
WHERE lp.landing_page IN ('/home', '/lander-1')
GROUP BY
    DATE(ws.created_at::TIMESTAMP),
    lp.landing_page
ORDER BY
    date,
    landing_page;


--Step 2: Calculate bounce rates during the selected test period
WITH eligible_sessions AS (
SELECT
	website_session_id,
	created_at::timestamp
FROM
	website_sessions
WHERE
--restrict analysis to the selected test period
	created_at::timestamp >= '2012-06-19'
	AND created_at::timestamp < '2012-07-30'),
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
	wp.website_session_id),
landing_pages AS (
SELECT
	wp.website_session_id,
	wp.pageview_url AS landing_page
FROM
		website_pageviews wp
JOIN first_pageview fp ON
		wp.website_pageview_id = fp.first_pageview_id
WHERE
	wp.pageview_url IN ('/home', '/lander-1')),
pageview_counts AS (
SELECT
	COUNT(*) AS pageview_count,
	lp.website_session_id,
	lp.landing_page
FROM
	landing_pages lp
JOIN website_pageviews wp ON
	lp.website_session_id = wp.website_session_id
GROUP BY
	lp.website_session_id,
	lp.landing_page)
--a bounce is defined as a session with exactly one pageview
SELECT
	landing_page,
	COUNT(*) AS total_sessions,
	SUM(CASE
		WHEN pageview_count = 1 THEN 1
		ELSE 0
	END) AS bounces,
	ROUND(AVG(CASE
		WHEN pageview_count = 1 THEN 1
		ELSE 0
	END) * 100, 2) AS bounce_rate
FROM
		pageview_counts
GROUP BY
	landing_page;
