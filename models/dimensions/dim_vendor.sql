-- models/dimensions/dim_vendor.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH distinct_vendors AS (
    -- Fetch all distinct vendor IDs, including 6, 7, and 99 (Unknown)
    SELECT DISTINCT vendor_id
    FROM {{ ref('stg_taxi_trips') }}
    WHERE vendor_id IS NOT NULL
),
vendor_details AS (
    SELECT
        vendor_id,
        FARM_FINGERPRINT(CAST(vendor_id AS STRING)) AS vendor_sk,
        
        -- Full Business names
        CASE vendor_id
            WHEN 1 THEN 'Creative Mobile Technologies, LLC'
            WHEN 2 THEN 'Curb Mobility, LLC'
            WHEN 6 THEN 'Myle Technologies Inc'    -- Assuming Myle/Legacy for ID 6
            WHEN 7 THEN 'Helix Payment System' -- Assuming Helix/Legacy for ID 7
            WHEN 99 THEN 'Unknown/Invalid Vendor'
            ELSE 'Unclassified'
        END AS vendor_name,
        
        -- Short names for reporting
        CASE vendor_id
            WHEN 1 THEN 'CMT'
            WHEN 2 THEN 'Curb'
            WHEN 6 THEN 'Myle'
            WHEN 7 THEN 'Helix'
            WHEN 99 THEN 'Unknown'
            ELSE 'Unclassified'
        END AS vendor_short_name,
        
        -- models/dimensions/dim_vendor.sql (Revised Vendor Attributes)

        -- Fleet Size Category (Based on observed market dominance and specialized function)
        CASE 
            WHEN vendor_id = 2 THEN 'Largest Market Share'
            WHEN vendor_id = 1 THEN 'High Market Share'
            WHEN vendor_id = 6 THEN 'Specialized NEMT Fleet' -- Unique focus on medical transport
            WHEN vendor_id = 7 THEN 'Payment Processor'        -- Unique focus on payment
            WHEN vendor_id = 99 THEN 'Unknown/N/A'
            ELSE 'Other'
        END AS fleet_size_category,
        
        -- Weather Response Capability (Based on operational focus)
        CASE 
            -- These are the core dispatch platforms, highly robust.
            WHEN vendor_id IN (1, 2) THEN 'High - Core Dispatch Systems' 
            
            -- Myle (6) focuses on NEMT, which may require specialized dispatch 
            -- and be less affected by general street-hail demand volatility.
            WHEN vendor_id = 6 THEN 'Medium - Specialized NEMT Dispatch' 
            
            -- Helix (7) is a payment processor; its data is reliable, but its fleet 
            -- response is entirely dependent on the dispatch system it's paired with.
            WHEN vendor_id = 7 THEN 'Low - Payment System Only'
            
            WHEN vendor_id = 99 THEN 'Low - Data Error'
            ELSE 'Unknown'
        END AS weather_response_capability,
        
        -- Market share estimate (Combining legacy share into main vendor)
        CASE 
            -- Assuming 1 and 6 combine for CMT's total share (~60%)
            WHEN vendor_id IN (1, 6) THEN 0.60
            -- Assuming 2 and 7 combine for Verifone's total share (~35%)
            WHEN vendor_id IN (2, 7) THEN 0.35
            WHEN vendor_id = 99 THEN 0.00
            ELSE 0.05
        END AS estimated_market_share
        
    FROM distinct_vendors
)
SELECT * FROM vendor_details