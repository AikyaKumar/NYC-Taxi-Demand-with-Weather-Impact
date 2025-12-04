-- models/facts/fct_taxi_weather_correlation.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH hourly_combined AS (
    SELECT
        DATETIME_TRUNC(t.pickup_timestamp, HOUR) AS analysis_hour,
        DATE(t.pickup_timestamp) AS analysis_date,
        EXTRACT(HOUR FROM t.pickup_timestamp) AS hour_of_day,
        
        -- Weather at that hour
        w.temperature_celsius,
        w.rain_mm,
        w.snowfall_mm,
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
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),
enriched AS (
    SELECT
        -- Surrogate key
        FARM_FINGERPRINT(CAST(hc.analysis_hour AS STRING)) AS correlation_sk,
        
        -- Time dimensions
        hc.analysis_hour,
        hc.hour_of_day,
        tod.time_band,
        tod.commute_period,
        tod.weather_sensitivity_band,
        
        -- Date dimensions
        d.date_key,
        d.year,
        d.month,
        d.month_name,
        d.day_name,
        d.is_weekend,
        d.is_holiday,
        d.season,
        d.tourism_season,
        
        -- Weather dimensions
        wc.weather_description,
        wc.weather_category,
        wc.weather_severity,
        wc.is_rainy,
        wc.is_snowy,
        wc.is_stormy,
        
        -- Weather measures
        hc.temperature_celsius,
        hc.rain_mm,
        hc.snowfall_mm,
        hc.wind_speed_kph,
        
        -- Taxi demand metrics
        hc.trip_count,
        hc.total_revenue,
        hc.avg_trip_distance,
        hc.avg_trip_duration,
        hc.avg_passengers,
        hc.total_tips,
        
        -- Derived metrics for correlation analysis
        hc.total_revenue / NULLIF(hc.trip_count, 0) AS avg_revenue_per_trip,
        hc.total_tips / NULLIF(hc.total_revenue - hc.total_tips, 0) AS tip_percentage,
        
        -- Weather impact scores
        CASE 
            WHEN hc.rain_mm > 2 THEN 'Heavy Rain Impact'
            WHEN hc.rain_mm > 0 THEN 'Light Rain Impact'
            WHEN hc.snowfall_mm > 0 THEN 'Snow Impact'
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