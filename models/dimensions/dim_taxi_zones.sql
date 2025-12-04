-- models/dimensions/dim_taxi_zones.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH zones AS (
    SELECT
        -- Already has location_id which is a natural key
        location_id,
        borough,
        zone_name,
        service_zone,
        -- Create a surrogate key if needed (optional since location_id is already unique)
        FARM_FINGERPRINT(CONCAT(CAST(location_id AS STRING), zone_name)) AS zone_sk
    FROM {{ ref('stg_taxi_zones') }}
    WHERE location_id IS NOT NULL
      AND borough IS NOT NULL
      AND zone_name IS NOT NULL
)
SELECT * FROM zones