-- models/marts/mart_taxi_weather_hourly.sql

{{ config(materialized='table') }}

SELECT
    t.pickup_hour,
    t.zone_id,
    t.borough,
    t.zone_name,
    -- Taxi metrics
    t.trips_count,
    t.avg_trip_duration_min,
    t.avg_fare,
    t.total_revenue,
    -- Weather metrics (HOURLY join!)
    w.temperature_2m,
    w.rain_mm,
    w.precipitation_mm,
    w.weather_code
FROM {{ ref('fct_taxi_trips_hourly') }} t
LEFT JOIN {{ ref('stg_weather') }} w 
    ON t.pickup_hour = w.weather_hour;
