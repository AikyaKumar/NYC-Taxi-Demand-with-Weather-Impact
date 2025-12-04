-- models/facts/fct_trip_weather_details.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH trip_weather AS (
    SELECT
        -- Trip Surrogate Key
        t.trip_sk,
        
        -- Time Dimensions
        dt.datetime_sk AS pickup_datetime_sk,
        dd.date_key AS pickup_date_key,
        tod.hour_key AS pickup_hour_key,
        
        -- Location Dimensions
        dz_pickup.zone_sk AS pickup_zone_sk,
        dz_dropoff.zone_sk AS dropoff_zone_sk,
        
        -- Other Dimensions
        v.vendor_sk,
        pt.payment_sk,
        
        -- Weather at EXACT Pickup Time (closest hour)
        w.temperature_celsius AS pickup_temp_c,
        w.rain_mm AS pickup_rain_mm,
        w.snowfall_mm AS pickup_snow_mm,
        w.wind_speed_kph AS pickup_wind_speed,
        w.weather_code AS pickup_weather_code,
        
        -- Weather Conditions Dimension
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
        
        -- Weather Impact Flags
        CASE 
            WHEN w.rain_mm > 2 THEN 'Heavy Rain Trip'
            WHEN w.rain_mm > 0 THEN 'Light Rain Trip'
            WHEN w.snowfall_mm > 0 THEN 'Snow Trip'
            WHEN w.temperature_celsius > 30 THEN 'Hot Weather Trip'
            WHEN w.temperature_celsius < 0 THEN 'Cold Weather Trip'
            ELSE 'Normal Weather Trip'
        END AS weather_condition_at_pickup
        
    FROM {{ ref('stg_taxi_trips') }} t
    
    -- Time Dimensions
    LEFT JOIN {{ ref('dim_date_time') }} dt 
        ON t.pickup_timestamp = dt.datetime_key
    
    LEFT JOIN {{ ref('dim_date') }} dd 
        ON DATE(t.pickup_timestamp) = dd.date_key
    
    LEFT JOIN {{ ref('dim_time_of_day') }} tod
        ON EXTRACT(HOUR FROM t.pickup_timestamp) = tod.hour_key
    
    -- Location Dimensions
    LEFT JOIN {{ ref('dim_taxi_zones') }} dz_pickup
        ON t.pickup_location_id = dz_pickup.location_id
    
    LEFT JOIN {{ ref('dim_taxi_zones') }} dz_dropoff
        ON t.dropoff_location_id = dz_dropoff.location_id
    
    -- Other Dimensions
    LEFT JOIN {{ ref('dim_vendor') }} v
        ON t.vendor_id = v.vendor_id
    
    LEFT JOIN {{ ref('dim_payment_type') }} pt
        ON t.payment_type = pt.payment_type
    
    -- Weather Data (hourly precision - closest hour)
    LEFT JOIN {{ ref('stg_weather') }} w
        ON DATETIME_TRUNC(t.pickup_timestamp, HOUR) = DATETIME_TRUNC(w.weather_timestamp, HOUR)
    
    LEFT JOIN {{ ref('dim_weather_conditions') }} wc
        ON w.weather_code = wc.weather_code
    
    WHERE t.pickup_timestamp IS NOT NULL
)

SELECT * FROM trip_weather