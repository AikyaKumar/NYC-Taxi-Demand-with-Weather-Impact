-- models/facts/fct_trip_weather_details.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH trip_weather AS (
    SELECT
        -- Primary Key
        t.trip_sk,
        
        -- Time Dimension Foreign Keys (Joining on Surrogate Keys)
        dt.datetime_sk AS pickup_datetime_sk,
        dd.date_key AS pickup_date_key,
        tod.hour_key AS pickup_hour_key,
        
        -- Location Dimension Foreign Keys
        dz_pickup.zone_sk AS pickup_zone_sk,
        dz_dropoff.zone_sk AS dropoff_zone_sk,
        
        -- Other Dimension Foreign Keys
        dv.vendor_sk,
        dpt.payment_sk,
        wc.weather_sk AS pickup_weather_sk, -- Use weather_sk as the FK
        
        -- Raw Weather Measures (Retained from stg_weather for correlation)
        w.temperature_celsius AS pickup_temp_c,
        w.precipitation_mm AS pickup_precipitation_mm,
        w.wind_speed_kph AS pickup_wind_speed,
        
        -- Weather Dimension Attributes (Preferred for analysis)
        wc.weather_description AS pickup_weather_desc,
        wc.weather_category AS pickup_weather_category,
        wc.weather_severity AS pickup_weather_severity,
        wc.is_rainy AS was_rainy,
        wc.is_snowy AS was_snowy,
        
        -- Trip Metrics
        t.passenger_count,
        t.trip_distance,
        
        -- Financial Metrics
        t.fare_amount,
        t.extra,
        t.mta_tax,
        t.tip_amount,
        t.tolls_amount,
        t.improvement_surcharge,
        t.total_amount,
        
        -- Duration
        DATETIME_DIFF(t.dropoff_timestamp, t.pickup_timestamp, MINUTE) AS trip_duration_minutes,
        
        -- Weather Impact Flags (Using the dimensional severity for better categorization)
        CASE 
            WHEN wc.weather_severity = 'Extreme (Major Disruption)' THEN 'Severe Weather Trip'
            WHEN wc.weather_severity = 'Poor (Moderate Impact)' THEN 'Moderate Weather Trip'
            WHEN wc.weather_severity = 'Fair (Light Impact)' THEN 'Light Weather Trip'
            ELSE 'Normal Conditions Trip'
        END AS weather_condition_at_pickup
        
    FROM {{ ref('stg_taxi_trips') }} t
    
    -- Time Dimensions
    -- CRITICAL FIX: Joins on Natural Key, SELECT on Surrogate Key
    LEFT JOIN {{ ref('dim_date_time') }} dt ON t.pickup_timestamp = dt.datetime_key
    LEFT JOIN {{ ref('dim_date') }} dd ON DATE(t.pickup_timestamp) = dd.date_key
    LEFT JOIN {{ ref('dim_time_of_day') }} tod ON EXTRACT(HOUR FROM t.pickup_timestamp) = tod.hour_key
    
    -- Location Dimensions
    LEFT JOIN {{ ref('dim_taxi_zones') }} dz_pickup
        ON t.pickup_location_id = dz_pickup.location_id
    LEFT JOIN {{ ref('dim_taxi_zones') }} dz_dropoff
        ON t.dropoff_location_id = dz_dropoff.location_id
    
    -- Other Dimensions
    LEFT JOIN {{ ref('dim_vendor') }} dv
        ON t.vendor_id = dv.vendor_id
    LEFT JOIN {{ ref('dim_payment_type') }} dpt
        ON t.payment_type = dpt.payment_type
    
    -- Weather Data (hourly precision)
    LEFT JOIN {{ ref('stg_weather') }} w
        ON t.pickup_hour = w.weather_timestamp -- Uses the pre-truncated pickup_hour from staging
    
    -- Weather Conditions Dimension (Joined on the raw code from stg_weather)
    LEFT JOIN {{ ref('dim_weather_conditions') }} wc
        ON w.weather_code = wc.weather_code
    
    WHERE t.pickup_timestamp IS NOT NULL
)

SELECT * FROM trip_weather