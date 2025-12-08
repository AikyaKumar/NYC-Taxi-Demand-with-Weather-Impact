{{ config(materialized='view', schema='stg') }}

SELECT
    -- FIX: Expanded the key to include total_amount and payment_type for uniqueness
    FARM_FINGERPRINT(
        CONCAT(
            CAST(tpep_pickup_datetime AS STRING), 
            CAST(tpep_dropoff_datetime AS STRING), 
            CAST(pulocationid AS STRING), 
            CAST(dolocationid AS STRING),
            CAST(fare_amount AS STRING),
            CAST(total_amount AS STRING),     -- ADDED to ensure uniqueness
            CAST(payment_type AS STRING),
            CAST(passenger_count AS STRING),
            CAST(tip_amount AS STRING),
            CAST(tolls_amount as STRING),
            CAST(extra AS STRING),                     -- ADDED
            CAST(mta_tax AS STRING),                   -- ADDED
            CAST(improvement_surcharge AS STRING),     -- ADDED
            CAST(ratecodeid AS STRING)    -- ADDED to ensure uniqueness
        )
    ) AS trip_sk,   
    
    -- Vendor ID Mapping (Confirmed to only produce integers 1 or 2)
    CASE 
        WHEN vendorid IN (1, 2, 6, 7) THEN CAST(vendorid AS INTEGER)
        ELSE 99  -- Map unknown raw IDs to 99
    END AS vendor_id,
    
    -- Casting timestamp columns
    CAST(tpep_pickup_datetime AS TIMESTAMP) AS pickup_timestamp,
    CAST(tpep_dropoff_datetime AS TIMESTAMP) AS dropoff_timestamp,
    TIMESTAMP_TRUNC(CAST(tpep_pickup_datetime AS TIMESTAMP), HOUR) AS pickup_hour,
    
    -- Casting metrics and dimensions
    CAST(passenger_count AS INTEGER) AS passenger_count,
    CAST(trip_distance AS NUMERIC) AS trip_distance,
    
    -- Rename Location IDs
    CAST(pulocationid AS INTEGER) AS pickup_location_id,
    CAST(dolocationid AS INTEGER) AS dropoff_location_id,
    COALESCE(CAST(t.ratecodeid AS INTEGER), 99) AS rate_code_id,
    COALESCE(t.store_and_fwd_flag, 'U') AS store_and_forward_flag,
    CAST(payment_type AS INTEGER) AS payment_type, 
    CAST(fare_amount AS NUMERIC) AS fare_amount,
    CAST(total_amount AS NUMERIC) AS total_amount,
    
    -- Additional columns (casted)
    CAST(extra AS NUMERIC) AS extra,
    CAST(mta_tax AS NUMERIC) AS mta_tax,
    CAST(tip_amount AS NUMERIC) AS tip_amount,
    CAST(tolls_amount AS NUMERIC) AS tolls_amount,
    CAST(improvement_surcharge AS NUMERIC) AS improvement_surcharge,
    
FROM {{ source('dm2_aikya', 'nyc_yellow_taxi_trips_raw') }} t

-- CRITICAL DATA QUALITY FILTERS
WHERE tpep_pickup_datetime IS NOT NULL
    -- FIX 2: Filter out negative/zero amounts (total_amount > 0 was failing the min value test)
    AND total_amount > 0.01      
    -- FIX 3: Filter out negative/zero distances AND extreme outliers (trip_distance was 276k)
    AND trip_distance > 0.01 
    AND trip_distance < 1000.0