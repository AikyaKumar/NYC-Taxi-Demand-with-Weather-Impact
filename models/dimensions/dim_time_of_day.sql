-- models/dimensions/dim_time_of_day.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH all_hours AS (
    SELECT hour
    FROM UNNEST(GENERATE_ARRAY(0, 23)) AS hour
)
SELECT
    hour AS hour_key,
    
    -- Business time classifications
    CASE
        WHEN hour BETWEEN 6 AND 9 THEN 'Morning Rush'
        WHEN hour BETWEEN 16 AND 19 THEN 'Evening Rush'
        WHEN hour BETWEEN 10 AND 15 THEN 'Midday'
        WHEN hour BETWEEN 20 AND 23 THEN 'Night'
        WHEN hour BETWEEN 0 AND 5 THEN 'Late Night'
    END AS time_band,
    
    CASE
        WHEN hour BETWEEN 7 AND 9 THEN 'Morning Commute'
        WHEN hour BETWEEN 17 AND 19 THEN 'Evening Commute'
        ELSE 'Non-Commute'
    END AS commute_period,
    
    -- Business hours
    CASE
        WHEN hour BETWEEN 9 AND 17 THEN TRUE
        ELSE FALSE
    END AS is_business_hour,
    
    -- Weather impact relevance
    CASE
        WHEN hour BETWEEN 7 AND 9 THEN 'High Weather Impact'
        WHEN hour BETWEEN 17 AND 19 THEN 'High Weather Impact'
        WHEN hour BETWEEN 22 AND 5 THEN 'Low Weather Impact'
        ELSE 'Medium Weather Impact'
    END AS weather_sensitivity_band
    
FROM all_hours