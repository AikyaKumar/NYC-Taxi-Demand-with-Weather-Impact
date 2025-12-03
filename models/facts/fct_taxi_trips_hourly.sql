-- models/facts/fct_taxi_trips_hourly.sql

{{ config(materialized='table') }}

WITH hourly_trips AS (
    SELECT
        DATETIME_TRUNC(pickup_timestamp, HOUR) AS pickup_hour,
        pickup_location_id AS zone_id,
        COUNT(*) AS trips_count,
        AVG(trip_duration_minutes) AS avg_trip_duration_min,
        AVG(total_amount) AS avg_fare,
        SUM(total_amount) AS total_revenue,
        AVG(passenger_count) AS avg_passengers
    FROM {{ ref('stg_taxi_trips') }}
    GROUP BY pickup_hour, zone_id
)

SELECT
    h.*,
    z.borough,
    z.zone_name
FROM hourly_trips h
LEFT JOIN {{ ref('stg_taxi_zones') }} z ON h.zone_id = z.location_id;
