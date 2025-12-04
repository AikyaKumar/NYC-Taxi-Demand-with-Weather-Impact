-- models/dimensions/dim_vendor.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH distinct_vendors AS (
    SELECT DISTINCT vendor_id
    FROM {{ ref('stg_taxi_trips') }}
    WHERE vendor_id IS NOT NULL
),
vendor_details AS (
    SELECT
        vendor_id,
        -- Create a surrogate key
        FARM_FINGERPRINT(CAST(vendor_id AS STRING)) AS vendor_sk,
        -- Add business-friendly names
        CASE vendor_id
            WHEN 1 THEN 'Creative Mobile Technologies'
            WHEN 2 THEN 'Verifone'
            ELSE 'Unknown'
        END AS vendor_name,
        CASE vendor_id
            WHEN 1 THEN 'CMT'
            WHEN 2 THEN 'Verifone'
            ELSE 'Unknown'
        END AS vendor_short_name
    FROM distinct_vendors
)
SELECT * FROM vendor_details