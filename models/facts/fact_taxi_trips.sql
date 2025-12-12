-- models/facts/fct_taxi_trips.sql
-- Materialized as a TABLE in schema dm2_aikya_analytics
-- This model is the central hub for all trip analysis.

WITH trips AS (
    -- 1. Select base trip data from the staging model
    SELECT * FROM {{ ref('stg_taxi_trips') }}
),

weather AS (
    -- 2. Select only the necessary SK and timestamp from the staging model
    SELECT weather_sk, weather_timestamp
    -- NOTE: Corrected reference from 'stg_weather' to 'stg_weather' based on your previous models
    FROM {{ ref('stg_weather') }}
),

final AS (
    SELECT
        -- PRIMARY KEY: Trip Surrogate Key from Staging
        t.trip_sk,

        -- 1. FOREIGN KEYS (SKs) for Dimension Joins
        t.vendor_id AS vendor_sk,
        t.pickup_location_id AS pickup_location_sk,
        t.dropoff_location_id AS dropoff_location_sk,
        timestamp_trunc(t.pickup_datetime, HOUR) AS pickup_date_time_sk,
        w.weather_sk,
        t.payment_type_id AS payment_type_sk, 
        t.ratecode_id AS ratecode_sk,

        -- 2. CALCULATED METRICS (Your Requirements)
        TIMESTAMP_DIFF(t.dropoff_datetime, t.pickup_datetime, MINUTE) AS trip_duration_minutes,

        -- 3. CORE METRICS (Facts)
        t.passenger_count,
        t.trip_distance,
        t.store_and_fwd_flag,
        
        -- 4. FINANCIAL COMPONENTS (FIXED: Changed t.extra and t.mta_tax)
        t.fare_amount,
        t.tip_amount,
        t.tolls_amount,
        t.extra_amount,  -- <-- FIX 2
        t.mta_tax_amount,  -- <-- FIX 3 (mta_tax was also renamed in staging)
        t.improvement_surcharge,
        t.congestion_surcharge,
        t.airport_fee,
        t.total_amount 

    FROM trips t
    
    -- Joining to weather data on the closest hour of pickup (matching dim_weather granularity)
    LEFT JOIN weather w
        ON timestamp_trunc(t.pickup_datetime, HOUR) = w.weather_timestamp
)

SELECT *
FROM final
