-- models/marts/mart_financial_behavior_analysis.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH trip_aggregates AS (
    SELECT
        -- Grouping Dimensions (Natural Keys for simplicity in the mart)
        wc.weather_category,
        wc.weather_severity,
        tod.commute_period,
        dpt.payment_method,
        dpt.transaction_speed_category,
        
        -- Aggregated Metrics (Calculated at the grouping level)
        COUNT(f.trip_sk) AS total_trips,
        SUM(f.total_amount) AS total_revenue,
        SUM(f.tip_amount) AS total_tips,
        
        -- Specialized Metrics
        AVG(f.trip_distance) AS avg_trip_distance,
        AVG(f.trip_duration_minutes) AS avg_trip_duration,
        
        -- Tip calculation (only on trips where tipping is possible, i.e., Credit Card)
        SUM(CASE WHEN dpt.payment_method = 'Credit Card' THEN f.tip_amount ELSE 0 END) AS credit_card_tips,
        SUM(CASE WHEN dpt.payment_method = 'Credit Card' THEN f.total_amount ELSE 0 END) AS credit_card_revenue_eligible_for_tip
        
    FROM {{ ref('fct_trip_weather_details') }} f
    
    -- Join Dimensions
    LEFT JOIN {{ ref('dim_weather_conditions') }} wc ON f.pickup_weather_sk = wc.weather_sk
    LEFT JOIN {{ ref('dim_payment_type') }} dpt ON f.payment_sk = dpt.payment_sk
    LEFT JOIN {{ ref('dim_time_of_day') }} tod ON f.pickup_hour_key = tod.hour_key
    
    GROUP BY 1, 2, 3, 4, 5
)

SELECT
    -- Grouping Attributes
    ta.weather_category,
    ta.weather_severity,
    ta.commute_period,
    ta.payment_method,
    ta.transaction_speed_category,
    
    -- Metrics
    ta.total_trips,
    ta.total_revenue,
    ta.total_tips,
    ta.avg_trip_distance,
    ta.avg_trip_duration,
    
    -- Derived Metrics for Behavior Analysis
    
    -- 1. Overall Tip Percentage (All trips, though mostly credit card)
    SAFE_DIVIDE(ta.total_tips, ta.total_revenue) * 100 AS overall_average_tip_pct,
    
    -- 2. Credit Card Tip Percentage (Most reliable metric)
    SAFE_DIVIDE(ta.credit_card_tips, NULLIF(ta.credit_card_revenue_eligible_for_tip, 0)) * 100 AS credit_card_tip_pct,
    
    -- 3. Payment Method Share (Within the weather/time group)
    SAFE_DIVIDE(ta.total_trips, SUM(ta.total_trips) OVER (PARTITION BY ta.weather_severity, ta.commute_period)) * 100 AS payment_share_within_scenario_pct,
    
    -- 4. Payment Volatility Flag
    CASE
        WHEN ta.payment_method = 'Cash' AND ta.total_trips < 
             AVG(ta.total_trips) OVER (PARTITION BY ta.commute_period) * 0.5
             THEN 'High Cash Volatility (Drop)'
        WHEN ta.payment_method IN ('Credit Card', 'Flex Fare Trip') AND ta.total_trips > 
             AVG(ta.total_trips) OVER (PARTITION BY ta.commute_period) * 1.5
             THEN 'High Electronic Volatility (Surge)'
        ELSE 'Normal Volatility'
    END AS payment_volatility_flag
    
FROM trip_aggregates ta
ORDER BY ta.weather_severity DESC, ta.commute_period, ta.payment_method