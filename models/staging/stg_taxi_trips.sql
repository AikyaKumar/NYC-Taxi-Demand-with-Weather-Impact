{{ config(materialized='view', schema='stg') }}

SELECT
    -- Generate surrogate key (matches your YAML)
    FARM_FINGERPRINT(
        CONCAT(
            CAST(tpep_pickup_datetime AS STRING), 
            CAST(pulocationid AS STRING), 
            CAST(dolocationid AS STRING)
        )
    ) AS trip_sk,
    
    CASE 
        WHEN vendorid IN (1, 2) THEN vendorid
        WHEN vendorid = 6 THEN 1  -- Map vendor 6 to 1
        WHEN vendorid = 7 THEN 2  -- Map vendor 7 to 2
        ELSE 1  -- Default to vendor 1 for any other values
    END AS vendor_id,
    
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
    total_amount,
    
    -- Additional columns (you might want to add to YAML)
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    
    -- Hour for partitioning/analysis
    TIMESTAMP_TRUNC(CAST(tpep_pickup_datetime AS TIMESTAMP), HOUR) AS pickup_hour
    
-- CORRECTED SOURCE NAME: 'dm2_aikya' not 'dm2_aikya_raw'
FROM {{ source('dm2_aikya', 'nyc_yellow_taxi_trips_raw') }}
WHERE tpep_pickup_datetime IS NOT NULL
    AND total_amount > 0        -- Fixes 217k rows failing the total_amount test
    AND trip_distance > 0       -- Fixes 458 rows failing the trip_distance test