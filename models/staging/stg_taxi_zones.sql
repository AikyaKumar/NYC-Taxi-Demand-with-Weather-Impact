-- models/staging/stg_taxi_zones.sql

select

    -- Primary Key: The natural key is suitable for this dimension table
    cast(LocationID as int) as location_id,

    -- Renamed Fields (snake_case convention)
    Borough as borough,
    Zone as zone_name,
    service_zone,

-- Direct reference to the BigQuery table path:
from `dm2-project-479611.dm2_aikya.nyc_taxi_zones_raw`