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
        FARM_FINGERPRINT(CAST(vendor_id AS STRING)) AS vendor_sk,
        
        -- Business names
        CASE vendor_id
            WHEN 1 THEN 'Creative Mobile Technologies'
            WHEN 2 THEN 'Verifone'
            ELSE 'Unknown'
        END AS vendor_name,
        
        CASE vendor_id
            WHEN 1 THEN 'CMT'
            WHEN 2 THEN 'Verifone'
            ELSE 'Unknown'
        END AS vendor_short_name,
        
        -- Weather Response Characteristics
        CASE 
            WHEN vendor_id = 1 THEN 'Large Fleet Operator'
            WHEN vendor_id = 2 THEN 'Medium Fleet Operator'
            ELSE 'Small/Unknown Fleet'
        END AS fleet_size_category,
        
        -- Hypothetical weather response capability
        CASE 
            WHEN vendor_id = 1 THEN 'High - Multiple dispatch systems'
            WHEN vendor_id = 2 THEN 'Medium - Standard dispatch'
            ELSE 'Low - Limited systems'
        END AS weather_response_capability,
        
        -- Market share estimate for normalization
        CASE 
            WHEN vendor_id = 1 THEN 0.6  -- 60% market share
            WHEN vendor_id = 2 THEN 0.35 -- 35% market share
            ELSE 0.05                     -- 5% other
        END AS estimated_market_share
        
    FROM distinct_vendors
)
SELECT * FROM vendor_details