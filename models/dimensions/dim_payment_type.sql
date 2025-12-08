-- models/dimensions/dim_payment_type.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH payment_codes AS (
    -- Include payment_type 0, 1, 2, 3, 4, 5, 6, and any other distinct non-null codes
    SELECT DISTINCT payment_type
    FROM {{ ref('stg_taxi_trips') }}
    WHERE payment_type IS NOT NULL
),

payment_details AS (
    SELECT
        payment_type,
        -- Generate surrogate key
        FARM_FINGERPRINT(CAST(payment_type AS STRING)) AS payment_sk,
        
        -- Standard descriptions (Updated to include Flex Fare)
        CASE payment_type
            WHEN 0 THEN 'Flex Fare Trip'
            WHEN 1 THEN 'Credit Card'
            WHEN 2 THEN 'Cash'
            WHEN 3 THEN 'No Charge'
            WHEN 4 THEN 'Dispute'
            WHEN 5 THEN 'Unknown'
            WHEN 6 THEN 'Voided Trip'
            ELSE 'Unclassified' -- Catch any codes outside the 0-6 range
        END AS payment_method,
        
        -- Categorizing payment status
        CASE 
            WHEN payment_type IN (1, 2, 0) THEN 'Paid or Guaranteed' -- Flex Fare is guaranteed payment
            WHEN payment_type = 3 THEN 'Administrative/Free'
            WHEN payment_type IN (4, 6) THEN 'Dispute/Voided'
            ELSE 'Unknown Status'
        END AS payment_status,
        
        -- Weather Impact Analysis: How payment method affects trip security/choice in bad weather
        CASE 
            WHEN payment_type = 1 THEN 'Electronic - High Resilience' -- Reliable and convenient in bad weather
            WHEN payment_type = 0 THEN 'Electronic - Guaranteed/App'  -- Payment settled via app is stable
            WHEN payment_type = 2 THEN 'Cash - Lower Resilience'    -- Requires interaction, less convenient in bad weather
            ELSE 'Issue/Non-Revenue'
        END AS weather_payment_category,
        
        -- Transaction speed (for efficiency analysis)
        CASE 
            WHEN payment_type IN (1, 0) THEN 'Fast - Electronic/App' -- Automatic processing is fast
            WHEN payment_type = 2 THEN 'Medium - Cash Handling'    -- Requires driver interaction
            ELSE 'Slow - Disputes/Issues'
        END AS transaction_speed_category
        
    FROM payment_codes
)
SELECT * FROM payment_details