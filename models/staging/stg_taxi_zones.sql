-- models/staging/stg_taxi_zones.sql

SELECT
    CAST(LocationID AS INT64) AS location_id, -- Ensure it's a clean integer
    Borough AS borough,
    Zone AS zone_name,
    service_zone
FROM {{ source('dm2_aikya_raw', 'nyc_taxi_zones_raw') }}