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
        END AS payment_status
    FROM payment_codes
)
SELECT * FROM payment_details