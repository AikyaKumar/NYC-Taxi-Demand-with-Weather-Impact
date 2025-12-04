{{ config(materialized='view', schema='stg') }}

SELECT
    CAST(LocationID AS INT64) AS location_id,
    Borough AS borough,
    Zone AS zone_name,
    service_zone
FROM {{ source('dm2_aikya', 'nyc_taxi_zones_raw') }}
WHERE LocationID IS NOT NULL