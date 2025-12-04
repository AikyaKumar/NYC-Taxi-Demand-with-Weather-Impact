-- models/marts/mart_hourly_weather_patterns.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

SELECT
    -- Time Dimensions
    tod.hour_key,
    tod.time_band,
    tod.commute_period,
    tod.weather_sensitivity_band,
    
    -- Weather Conditions
    wc.weather_category,
    wc.weather_severity,
    wc.is_rainy,
    wc.is_snowy,
    
    -- Aggregated Metrics (from your existing mart + new)
    COUNT(DISTINCT f.date_key) AS days_observed,
    SUM(f.trip_count) AS total_trips,
    SUM(f.total_revenue) AS total_revenue,
    AVG(f.trip_count) AS avg_hourly_trips,
    AVG(f.total_revenue) AS avg_hourly_revenue,
    AVG(f.temperature_celsius) AS avg_temperature,
    AVG(f.rain_mm) AS avg_rainfall,
    AVG(f.snowfall_mm) AS avg_snowfall,
    
    -- Payment Patterns
    AVG(f.credit_card_percentage) AS avg_credit_card_usage,
    
    -- Vendor Patterns
    AVG(f.cmt_market_share) AS avg_cmt_market_share,
    
    -- Efficiency Metrics
    AVG(f.avg_revenue_per_trip) AS avg_revenue_per_trip,
    AVG(f.tip_percentage) AS avg_tip_percentage,
    AVG(f.avg_trip_duration) AS avg_trip_duration,
    
    -- Impact Ratios (for Tableau calculations)
    AVG(f.trip_count) / AVG(AVG(f.trip_count)) OVER (PARTITION BY tod.time_band) 
        AS demand_ratio_vs_time_band,
    
    AVG(f.total_revenue) / AVG(AVG(f.total_revenue)) OVER (PARTITION BY wc.weather_category) 
        AS revenue_ratio_vs_weather,
    
    -- Weather Impact Score
    CASE 
        WHEN wc.is_rainy = TRUE AND tod.commute_period = 'Commute Hours' THEN 'High Impact Scenario'
        WHEN wc.is_snowy = TRUE AND tod.commute_period = 'Commute Hours' THEN 'High Impact Scenario'
        WHEN wc.is_rainy = TRUE AND tod.time_band IN ('Morning Rush', 'Evening Rush') 
             THEN 'Medium Impact Scenario'
        ELSE 'Normal Scenario'
    END AS weather_impact_scenario
    
FROM {{ ref('fct_hourly_weather_impact') }} f
LEFT JOIN {{ ref('dim_time_of_day') }} tod ON f.hour_of_day = tod.hour_key
LEFT JOIN {{ ref('dim_weather_conditions') }} wc ON f.weather_sk = wc.weather_sk
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8