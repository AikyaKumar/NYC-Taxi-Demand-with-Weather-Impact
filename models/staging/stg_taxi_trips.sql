-- models/staging/stg_nyc_yellow_taxi_trips.sql

select

    -- Primary Key: Creating a robust, unique identifier for each trip
    -- Note: We still need the dbt_utils package for generate_surrogate_key
    {{ dbt_utils.generate_surrogate_key(['VendorID', 'tpep_pickup_datetime', 'tpep_dropoff_datetime']) }} as trip_sk,

    -- Renamed Fields (snake_case convention)
    cast(VendorID as int) as vendor_id,

    -- Date and Time Fields (Casting for consistency)
    cast(tpep_pickup_datetime as timestamp) as pickup_datetime,
    cast(tpep_dropoff_datetime as timestamp) as dropoff_datetime,

    -- Trip Details
    cast(passenger_count as int) as passenger_count,
    cast(trip_distance as numeric) as trip_distance,
    cast(RatecodeID as int) as ratecode_id,
    store_and_fwd_flag,

    -- Location IDs
    cast(PULocationID as int) as pickup_location_id,
    cast(DOLocationID as int) as dropoff_location_id,

    -- Financial Amounts
    cast(payment_type as int) as payment_type_id,
    cast(fare_amount as numeric) as fare_amount,
    cast(extra as numeric) as extra_amount,
    cast(mta_tax as numeric) as mta_tax_amount,
    cast(tip_amount as numeric) as tip_amount,
    cast(tolls_amount as numeric) as tolls_amount,
    cast(improvement_surcharge as numeric) as improvement_surcharge,
    cast(total_amount as numeric) as total_amount,
    cast(congestion_surcharge as numeric) as congestion_surcharge,
    cast(Airport_fee as numeric) as airport_fee,


-- Direct reference to the BigQuery table path:
from `dm2-project-479611.dm2_aikya.nyc_yellow_taxi_trips_raw`