-- models/staging/stg_taxi_trips.sql

SELECT
    vendorid AS vendor_id,
    
    -- Casting timestamp columns
    CAST(tpep_pickup_datetime AS TIMESTAMP) AS pickup_timestamp,
    CAST(tpep_dropoff_datetime AS TIMESTAMP) AS dropoff_timestamp,
    
    passenger_count,
    trip_distance,
    
    -- Rename Location IDs
    pulocationid AS pickup_location_id,
    dolocationid AS dropoff_location_id,
    
    ratecodeid AS rate_code_id,
    store_and_fwd_flag AS store_and_forward_flag,
    payment_type,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    total_amount,
    
    -- Create a unique key for the trip
    FARM_FINGERPRINT(CONCAT(CAST(tpep_pickup_datetime AS STRING), CAST(pulocationid AS STRING), CAST(dolocationid AS STRING))) AS trip_sk
    
FROM {{ source('dm2_aikya_raw', 'nyc_yellow_taxi_trips_raw') }}
WHERE tpep_pickup_datetime IS NOT NULL -- Simple data quality check