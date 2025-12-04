-- models/marts/mart_weather_impact_dashboard.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH daily_aggregates AS (
    SELECT
        dd.date_key,
        dd.year,
        dd.month_name,
        dd.day_name,
        dd.is_weekend,
        dd.is_holiday,
        dd.season,
        dd.tourism_season,
        
        -- Weather Summary
        APPROX_TOP_COUNT(wc.weather_category, 1)[OFFSET(0)].value AS dominant_weather,
        MAX(CASE WHEN wc.is_rainy THEN 1 ELSE 0 END) AS had_rain,
        MAX(CASE WHEN wc.is_snowy THEN 1 ELSE 0 END) AS had_snow,
        MAX(CASE WHEN wc.weather_severity = 'Severe' THEN 1 ELSE 0 END) AS had_severe_weather,
        
        AVG(f.temperature_celsius) AS avg_daily_temp,
        SUM(f.rain_mm) AS total_daily_rain,
        SUM(f.snowfall_mm) AS total_daily_snow,
        
        -- Taxi Performance (from your existing mart + new)
        SUM(f.trip_count) AS total_daily_trips,
        SUM(f.total_revenue) AS total_daily_revenue,
        AVG(f.avg_trip_distance) AS avg_daily_distance,
        AVG(f.avg_trip_duration) AS avg_daily_duration,
        AVG(f.avg_passengers) AS avg_daily_passengers,
        SUM(f.total_tips) AS total_daily_tips,
        
        -- Payment Distribution
        SUM(f.credit_card_trips) AS credit_card_trips,
        SUM(f.cash_trips) AS cash_trips,
        
        -- Vendor Distribution
        SUM(f.cmt_trips) AS cmt_trips,
        SUM(f.verifone_trips) AS verifone_trips
        
    FROM {{ ref('fct_hourly_weather_impact') }} f
    LEFT JOIN {{ ref('dim_date') }} dd ON f.date_key = dd.date_key
    LEFT JOIN {{ ref('dim_weather_conditions') }} wc ON f.weather_sk = wc.weather_sk
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),

baseline_calculation AS (
    SELECT
        *,
        -- Calculate baselines (excluding current day)
        AVG(total_daily_trips) OVER (
            PARTITION BY day_name, season 
            ORDER BY date_key 
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS baseline_trips,
        
        AVG(total_daily_revenue) OVER (
            PARTITION BY day_name, season
            ORDER BY date_key
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS baseline_revenue
        
    FROM daily_aggregates
)

SELECT
    date_key,
    year,
    month_name,
    day_name,
    is_weekend,
    is_holiday,
    season,
    tourism_season,
    
    -- Weather Conditions
    dominant_weather,
    had_rain,
    had_snow,
    had_severe_weather,
    avg_daily_temp,
    total_daily_rain,
    total_daily_snow,
    
    -- Performance Metrics
    total_daily_trips,
    total_daily_revenue,
    avg_daily_distance,
    avg_daily_duration,
    avg_daily_passengers,
    total_daily_tips,
    
    -- Distribution Metrics
    credit_card_trips,
    cash_trips,
    cmt_trips,
    verifone_trips,
    
    -- Baseline Comparisons
    baseline_trips,
    baseline_revenue,
    
    -- Impact Calculations
    (total_daily_trips - baseline_trips) / NULLIF(baseline_trips, 0) * 100 AS trip_impact_percentage,
    (total_daily_revenue - baseline_revenue) / NULLIF(baseline_revenue, 0) * 100 AS revenue_impact_percentage,
    
    -- Derived Efficiency Metrics
    total_daily_revenue / NULLIF(total_daily_trips, 0) AS revenue_per_trip,
    total_daily_tips / NULLIF(total_daily_revenue, 0) * 100 AS tip_percentage,
    
    -- Weather Impact Classification
    CASE
        WHEN (total_daily_trips - baseline_trips) / NULLIF(baseline_trips, 0) * 100 < -20 
             AND had_rain = 1 THEN 'Severe Rain Impact'
        WHEN (total_daily_trips - baseline_trips) / NULLIF(baseline_trips, 0) * 100 < -10 
             AND had_rain = 1 THEN 'Moderate Rain Impact'
        WHEN (total_daily_trips - baseline_trips) / NULLIF(baseline_trips, 0) * 100 < -20 
             AND had_snow = 1 THEN 'Severe Snow Impact'
        WHEN (total_daily_trips - baseline_trips) / NULLIF(baseline_trips, 0) * 100 < -10 
             AND had_snow = 1 THEN 'Moderate Snow Impact'
        WHEN ABS((total_daily_trips - baseline_trips) / NULLIF(baseline_trips, 0) * 100) < 5 
             THEN 'Minimal Weather Impact'
        WHEN (total_daily_trips - baseline_trips) / NULLIF(baseline_trips, 0) * 100 > 10 
             THEN 'Positive Weather Impact'
        ELSE 'Neutral Impact'
    END AS weather_impact_category
    
FROM baseline_calculation
WHERE baseline_trips IS NOT NULL
ORDER BY date_key DESC