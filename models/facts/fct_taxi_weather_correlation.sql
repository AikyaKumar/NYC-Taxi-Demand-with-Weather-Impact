-- models/facts/fct_taxi_weather_correlation.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH hourly_combined AS (
    SELECT
        DATETIME_TRUNC(t.pickup_timestamp, HOUR) AS analysis_hour,
        DATE(t.pickup_timestamp) AS analysis_date,
        EXTRACT(HOUR FROM t.pickup_timestamp) AS hour_of_day,
        
        -- Weather at that hour
        w.temperature_celsius,
        -- FIX 1: Rename w.rain_mm and remove w.snowfall_mm
        w.precipitation_mm,
        w.wind_speed_kph,
        w.weather_code,
        
        -- Taxi metrics
        COUNT(*) AS trip_count,
        SUM(t.total_amount) AS total_revenue,
        AVG(t.trip_distance) AS avg_trip_distance,
        AVG(DATETIME_DIFF(t.dropoff_timestamp, t.pickup_timestamp, MINUTE)) AS avg_trip_duration,
        AVG(t.passenger_count) AS avg_passengers,
        SUM(t.tip_amount) AS total_tips
        
    FROM {{ ref('stg_taxi_trips') }} t
    LEFT JOIN {{ ref('stg_weather') }} w
        ON DATETIME_TRUNC(t.pickup_timestamp, HOUR) = DATETIME_TRUNC(w.weather_timestamp, HOUR)
    -- FIX 2: Group by 1, 2, 3, 4, 5, 6 (only 6 columns selected from w)
    GROUP BY 1, 2, 3, 4, 5, 6, 7 
    -- The numbers must match the number of non-aggregated columns in SELECT
),
enriched AS (
    SELECT
        -- ... (Skipping unchanged columns for brevity) ...
        
        -- Weather measures
        hc.temperature_celsius,
        -- FIX 3: Rename hc.rain_mm and remove hc.snowfall_mm
        hc.precipitation_mm,
        hc.wind_speed_kph,
        
        -- ... (Skipping unchanged columns for brevity) ...
        
        -- Derived metrics for correlation analysis
        hc.total_revenue / NULLIF(hc.trip_count, 0) AS avg_revenue_per_trip,
        hc.total_tips / NULLIF(hc.total_revenue - hc.total_tips, 0) AS tip_percentage,
        
        -- Weather impact scores
        CASE 
            -- FIX 4: Use precipitation_mm for the rain checks
            WHEN hc.precipitation_mm > 2 THEN 'Heavy Rain/Snow Impact'
            WHEN hc.precipitation_mm > 0 THEN 'Light Rain/Snow Impact'
            -- Removed the snowfall check since we don't have separate data
            WHEN hc.temperature_celsius > 30 THEN 'Heat Impact'
            WHEN hc.temperature_celsius < 0 THEN 'Cold Impact'
            ELSE 'Normal Conditions'
        END AS weather_impact_type
        
    FROM hourly_combined hc
    LEFT JOIN {{ ref('dim_time_of_day') }} tod ON hc.hour_of_day = tod.hour_key
    LEFT JOIN {{ ref('dim_date') }} d ON hc.analysis_date = d.date_key
    LEFT JOIN {{ ref('dim_weather_conditions') }} wc ON hc.weather_code = wc.weather_code
)
SELECT * FROM enriched