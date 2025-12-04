-- models/dimensions/dim_date_time.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH distinct_timestamps AS (
    SELECT pickup_timestamp AS datetime_key FROM {{ ref('stg_taxi_trips') }}
    UNION DISTINCT
    SELECT dropoff_timestamp FROM {{ ref('stg_taxi_trips') }}
    UNION DISTINCT
    SELECT weather_timestamp FROM {{ ref('stg_weather') }}
    WHERE weather_timestamp IS NOT NULL
),
datetime_parts AS (
    SELECT
        datetime_key,
        FARM_FINGERPRINT(CAST(datetime_key AS STRING)) AS datetime_sk,
        DATE(datetime_key) AS date_key,
        TIME(datetime_key) AS time_key,
        EXTRACT(YEAR FROM datetime_key) AS year,
        EXTRACT(MONTH FROM datetime_key) AS month,
        EXTRACT(DAY FROM datetime_key) AS day_of_month,
        EXTRACT(DAYOFWEEK FROM datetime_key) AS day_of_week,
        FORMAT_DATE('%A', DATE(datetime_key)) AS day_name,
        EXTRACT(HOUR FROM datetime_key) AS hour_of_day,
        EXTRACT(MINUTE FROM datetime_key) AS minute_of_hour,
        
        -- Weather-Specific Time Classifications
        CASE
            WHEN EXTRACT(HOUR FROM datetime_key) BETWEEN 6 AND 9 THEN 'Morning Rush'
            WHEN EXTRACT(HOUR FROM datetime_key) BETWEEN 16 AND 19 THEN 'Evening Rush'
            ELSE 'Off-Peak'
        END AS peak_time_band,
        
        CASE
            WHEN EXTRACT(HOUR FROM datetime_key) BETWEEN 5 AND 11 THEN 'Morning'
            WHEN EXTRACT(HOUR FROM datetime_key) BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN EXTRACT(HOUR FROM datetime_key) BETWEEN 18 AND 23 THEN 'Evening'
            ELSE 'Night'
        END AS time_of_day,
        
        -- Weather Impact Relevance
        CASE
            WHEN EXTRACT(HOUR FROM datetime_key) BETWEEN 7 AND 9 THEN 'High Weather Impact'
            WHEN EXTRACT(HOUR FROM datetime_key) BETWEEN 17 AND 19 THEN 'High Weather Impact'
            WHEN EXTRACT(HOUR FROM datetime_key) BETWEEN 22 AND 5 THEN 'Low Weather Impact'
            ELSE 'Medium Weather Impact'
        END AS weather_sensitivity_level,
        
        -- Business/Leisure Classification
        CASE
            WHEN EXTRACT(HOUR FROM datetime_key) BETWEEN 9 AND 17 
                 AND EXTRACT(DAYOFWEEK FROM datetime_key) BETWEEN 2 AND 6 
                 THEN 'Business Hours'
            WHEN EXTRACT(HOUR FROM datetime_key) BETWEEN 18 AND 23 
                 OR EXTRACT(DAYOFWEEK FROM datetime_key) IN (1, 7)
                 THEN 'Leisure Hours'
            ELSE 'Other Hours'
        END AS business_leisure_band
        
    FROM distinct_timestamps
    WHERE datetime_key IS NOT NULL
)
SELECT * FROM datetime_parts