--Monthly website performance
--Calculates monthly traffic, orders, revenue, conversion rate, average order value (AOV), 
--revenue per session, month-over-month (MoM) changes

--monthly website traffic
WITH monthly_sessions AS (      	 
SELECT
	DATE_TRUNC('month', created_at::TIMESTAMP) AS month_start,
	COUNT(*) AS sessions
FROM
	website_sessions
GROUP BY
	month_start),
--monthly order and revenue metrics
monthly_orders AS (        			
SELECT
	DATE_TRUNC('month', created_at::TIMESTAMP) AS month_start,
	COUNT(*) AS orders,
	SUM(price_usd) AS revenue,
	AVG(price_usd) AS aov
FROM
	orders
GROUP BY
	month_start),
--combine traffic and commercial metrics	
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
	ms.month_start = mo.month_start),
--add previous month values for month-over-month calculations
month_lag AS (						
SELECT
	monthly_data.*,
	LAG(sessions) OVER (
ORDER BY
	month_start) AS previous_sessions,
	LAG(revenue) OVER (
ORDER BY
	month_start) AS previous_revenue,
	LAG(conversion_rate) OVER (
ORDER BY
	month_start) AS previous_conversion_rate
FROM
	monthly_data)
SELECT
	month_start::DATE AS month_start,
	TO_CHAR(month_start, 'Mon YYYY') AS month,
	orders,
	sessions,
	ROUND(conversion_rate, 2) AS conversion_rate,
	ROUND(revenue::NUMERIC, 2) AS revenue,
	ROUND(aov::NUMERIC, 2) AS aov,
	ROUND(rev_per_session::NUMERIC, 2) AS revenue_per_session,
	CASE
		WHEN month_start::DATE = DATE '2015-03-01' THEN NULL
		ELSE ROUND((sessions - previous_sessions) * 100.0 / previous_sessions, 2)
	END AS mom_growth_sessions,
	CASE
		WHEN month_start::DATE = DATE '2015-03-01' THEN NULL
		ELSE ROUND(((revenue - previous_revenue) * 100.0 / previous_revenue)::NUMERIC, 2)
	END AS mom_growth_revenue,
	CASE
		WHEN month_start::DATE = DATE '2015-03-01' THEN NULL
		ELSE ROUND(conversion_rate - previous_conversion_rate, 2)
	END AS conversion_change_pp,
	--flag March 2012 and 2015 as partial months
	month_start::DATE IN (DATE '2012-03-01', DATE '2015-03-01') AS is_partial_month      
FROM
	month_lag
ORDER BY
	month_start;