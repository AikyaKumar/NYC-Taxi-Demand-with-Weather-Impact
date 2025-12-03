-- models/facts/fct_taxi_trips.sql

SELECT
    t.trip_sk,
    t.vendor_id,
    t.pickup_timestamp,
    t.dropoff_timestamp,
    
    -- Dimension Keys
    t.pickup_location_id,
    t.dropoff_location_id,
    
    -- Join to weather data using the pickup date (simple hourly join might be better, but we use DATE here for simplicity)
    w.weather_date,
    
    t.passenger_count,
    t.trip_distance,
    t.rate_code_id,
    t.payment_type,
    
    -- Measures (amounts)
    t.fare_amount,
    t.tip_amount,
    t.total_amount,
    
    -- Derived measures
    DATETIME_DIFF(t.dropoff_timestamp, t.pickup_timestamp, MINUTE) AS trip_duration_minutes,
    t.total_amount / NULLIF(t.trip_distance, 0) AS avg_fare_per_mile

FROM {{ ref('stg_taxi_trips') }} t
LEFT JOIN {{ ref('stg_weather') }} w
    ON DATE(t.pickup_timestamp) = w.weather_date