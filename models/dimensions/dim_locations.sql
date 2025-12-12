-- models/dimensions/dim_locations.sql

select
    location_id as location_sk, -- Primary Key
    borough,
    zone_name,
    service_zone

from {{ ref('stg_taxi_zones') }}
where location_id is not null