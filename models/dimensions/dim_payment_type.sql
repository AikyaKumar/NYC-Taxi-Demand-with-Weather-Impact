-- models/dimensions/dim_payment_type.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH payment_codes AS (
    SELECT DISTINCT payment_type
    FROM {{ ref('stg_taxi_trips') }}
    WHERE payment_type IS NOT NULL
),
payment_details AS (
    SELECT
        payment_type,
        FARM_FINGERPRINT(CAST(payment_type AS STRING)) AS payment_sk,
        
        -- Standard descriptions
        CASE payment_type
            WHEN 1 THEN 'Credit Card'
            WHEN 2 THEN 'Cash'
            WHEN 3 THEN 'No Charge'
            WHEN 4 THEN 'Dispute'
            WHEN 5 THEN 'Unknown'
            WHEN 6 THEN 'Voided Trip'
            ELSE 'Unknown'
        END AS payment_method,
        
        CASE 
            WHEN payment_type IN (1, 2) THEN 'Paid'
            ELSE 'Not Paid'
        END AS payment_status,
        
        -- Weather Impact Analysis
        CASE 
            WHEN payment_type = 1 THEN 'Electronic - Weather Resilient'
            WHEN payment_type = 2 THEN 'Cash - Weather Sensitive'
            ELSE 'Other - Neutral'
        END AS weather_payment_category,
        
        -- Hypothetical weather behavior
        CASE 
            WHEN payment_type = 1 THEN 'Likely stable in bad weather'
            WHEN payment_type = 2 THEN 'May decrease in heavy rain'
            ELSE 'Variable'
        END AS weather_impact_trend,
        
        -- Transaction speed (for efficiency analysis)
        CASE 
            WHEN payment_type = 1 THEN 'Fast - Electronic'
            WHEN payment_type = 2 THEN 'Medium - Cash handling'
            ELSE 'Slow - Disputes/Issues'
        END AS transaction_speed_category
        
    FROM payment_codes
)
SELECT * FROM payment_details