-- models/dimensions/dim_taxi_zones.sql

SELECT
    location_id,
    borough,
    zone_name,
    service_zone
FROM {{ ref('stg_taxi_zones') }}
-- Add a unique key test (later, in a separate schema.yml file)