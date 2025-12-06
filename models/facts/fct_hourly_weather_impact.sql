-- models/facts/fct_hourly_weather_impact.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH hourly_trips AS (
    SELECT
        -- Time Dimensions
        DATETIME_TRUNC(t.pickup_timestamp, HOUR) AS analysis_hour,
        DATE(t.pickup_timestamp) AS analysis_date,
        EXTRACT(HOUR FROM t.pickup_timestamp) AS hour_of_day,
        
        -- Location Dimension (Needed for zone join)
        t.pickup_location_id,
        
        -- Weather Data (FIX: Use precipitation_mm)
        w.temperature_celsius,
        w.precipitation_mm,
        w.wind_speed_kph,
        w.weather_code,
        
        -- Aggregated Trip Metrics
        COUNT(*) AS trip_count,
        SUM(t.total_amount) AS total_revenue,
        AVG(t.trip_distance) AS avg_trip_distance,
        AVG(DATETIME_DIFF(t.dropoff_timestamp, t.pickup_timestamp, MINUTE)) AS avg_trip_duration,
        AVG(t.passenger_count) AS avg_passengers,
        SUM(t.tip_amount) AS total_tips,
        
        -- Payment Distribution (Needed for mart_weather_impact_dashboard)
        COUNT(CASE WHEN t.payment_type = 1 THEN 1 END) AS credit_card_trips,
        COUNT(CASE WHEN t.payment_type = 2 THEN 1 END) AS cash_trips,
        
        -- Vendor Distribution (Needed for mart_weather_impact_dashboard)
        COUNT(CASE WHEN t.vendor_id = 1 THEN 1 END) AS cmt_trips,
        COUNT(CASE WHEN t.vendor_id = 2 THEN 1 END) AS verifone_trips
        
    FROM {{ ref('stg_taxi_trips') }} t
    LEFT JOIN {{ ref('stg_weather') }} w
        ON DATETIME_TRUNC(t.pickup_timestamp, HOUR) = DATETIME_TRUNC(w.weather_timestamp, HOUR)
    -- Group by all non-aggregated columns (now 8)
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),

enriched AS (
    SELECT
        -- Surrogate Key
        FARM_FINGERPRINT(
            CONCAT(
                CAST(ht.analysis_hour AS STRING),
                '_',
                CAST(ht.pickup_location_id AS STRING)
            )
        ) AS hourly_impact_sk,
        
        -- FIX 1: Add date_key and zone_sk for downstream marts
        dd.date_key,
        dz.zone_sk, 
        
        -- Time Dimensions
        ht.analysis_hour,
        ht.hour_of_day,
        dt.datetime_sk,
        -- ... (other time/date attributes) ...
        
        -- Weather Dimensions
        wc.weather_sk,
        wc.weather_description,
        wc.weather_category,
        wc.weather_severity,
        wc.is_rainy,
        wc.is_snowy,
        
        -- Weather Measures
        ht.temperature_celsius,
        ht.precipitation_mm, -- FIX: Correct name
        ht.wind_speed_kph,
        
        -- Trip Demand Metrics
        ht.trip_count,
        ht.total_revenue,
        ht.avg_trip_distance,
        ht.avg_trip_duration,
        ht.avg_passengers,
        ht.total_tips,
        
        -- Payment & Vendor Metrics
        ht.credit_card_trips,
        ht.cash_trips,
        SAFE_DIVIDE(ht.credit_card_trips, ht.trip_count) * 100 AS credit_card_percentage,
        ht.cmt_trips,
        ht.verifone_trips,
        SAFE_DIVIDE(ht.cmt_trips, ht.trip_count) * 100 AS cmt_market_share,
        
        -- Derived Efficiency Metrics
        ht.total_revenue / NULLIF(ht.trip_count, 0) AS avg_revenue_per_trip,
        ht.total_tips / NULLIF(ht.total_revenue, 0) * 100 AS tip_percentage,
        
        -- Weather Impact Classification
        CASE 
            WHEN ht.precipitation_mm > 2 THEN 'Heavy Rain/Snow Impact'
            WHEN ht.precipitation_mm > 0 THEN 'Light Rain/Snow Impact'
            WHEN ht.temperature_celsius > 30 THEN 'Heat Impact'
            WHEN ht.temperature_celsius < 0 THEN 'Cold Impact'
            ELSE 'Normal Conditions'
        END AS weather_impact_type
        
    FROM hourly_trips ht
    
    -- Join all dimensions
    LEFT JOIN {{ ref('dim_date_time') }} dt ON ht.analysis_hour = dt.datetime_key
    LEFT JOIN {{ ref('dim_date') }} dd ON ht.analysis_date = dd.date_key
    LEFT JOIN {{ ref('dim_taxi_zones') }} dz ON ht.pickup_location_id = dz.location_id
    LEFT JOIN {{ ref('dim_weather_conditions') }} wc ON ht.weather_code = wc.weather_code
)

SELECT * FROM enriched