-- models/marts/mart_hourly_weather_patterns.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

SELECT
    -- Time Dimensions (Grouped by)
    f.hour_key, -- Use the FK from the fact table
    tod.time_band,
    tod.commute_period,
    tod.weather_sensitivity_band,
    
    -- Weather Conditions (Grouped by)
    f.weather_sk, -- Group by key first
    wc.weather_category,
    wc.weather_severity,
    wc.is_rainy,
    wc.is_snowy,
    
    -- Aggregated Metrics 
    COUNT(DISTINCT DATE(f.analysis_hour)) AS days_observed, -- Use DATE(analysis_hour) for distinct days
    SUM(f.trip_count) AS total_trips,
    SUM(f.total_revenue) AS total_revenue,
    
    -- Averages
    AVG(f.trip_count) AS avg_hourly_trips,
    AVG(f.total_revenue) AS avg_hourly_revenue,
    AVG(f.temperature_celsius) AS avg_temperature,
    AVG(f.precipitation_mm) AS avg_precipitation,
    AVG(f.wind_speed_kph) AS avg_wind_speed, -- Added wind speed for completeness
    
    -- Financial/Demand Patterns
    AVG(f.credit_card_percentage) AS avg_credit_card_usage,
    AVG(f.avg_revenue_per_trip) AS avg_revenue_per_trip,
    AVG(f.total_tips) / SUM(f.total_revenue) AS overall_tip_percentage_calc, -- Calculate total tip rate
    
    -- Vendor Patterns (Assuming market share is calculated in fct_hourly_weather_impact)
    AVG(f.cmt_trips) AS avg_cmt_trips_hourly, -- Use trip count as a more stable metric
    AVG(f.curb_trips) AS avg_curb_trips_hourly,
    
    -- Impact Ratios (using columns verified in the fact model)
    -- Normalize trip count relative to the average demand across the entire time band (e.g., Morning Rush)
    AVG(f.trip_count) / AVG(AVG(f.trip_count)) OVER (PARTITION BY tod.time_band) 
        AS demand_ratio_vs_time_band,
    
    -- Normalize revenue relative to the average revenue across all hours with the SAME weather category
    AVG(f.total_revenue) / AVG(AVG(f.total_revenue)) OVER (PARTITION BY wc.weather_category) 
        AS revenue_ratio_vs_weather,
    
    -- Weather Impact Score (Using the more accurate weather severity from the dimension table)
    CASE 
        WHEN wc.weather_severity IN ('Severe (Heavy Impact)', 'Extreme (Major Disruption)') 
             AND tod.commute_period = 'Commute Hours' THEN 'High Impact Scenario'
        WHEN wc.weather_severity = 'Poor (Moderate Impact)'
             AND tod.weather_sensitivity_band = 'High Weather Impact' THEN 'Medium Impact Scenario'
        ELSE 'Normal Scenario'
    END AS weather_impact_scenario
    
FROM {{ ref('fct_hourly_weather_impact') }} f

-- FIX: Join on the dedicated hour_key foreign key
LEFT JOIN {{ ref('dim_time_of_day') }} tod ON f.hour_key = tod.hour_key 
LEFT JOIN {{ ref('dim_weather_conditions') }} wc ON f.weather_sk = wc.weather_sk

-- Group by all non-aggregated columns, using keys and descriptive attributes
GROUP BY 
    1, 2, 3, 4, 5, 6, 7, 8, 9 
    -- 1: hour_key, 2: time_band, 3: commute_period, 4: weather_sensitivity_band, 5: weather_sk, 
    -- 6: weather_category, 7: weather_severity, 8: is_rainy, 9: is_snowy