-- models/dimensions/dim_date_time.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH distinct_timestamps AS (
    -- Combine all relevant timestamps (pickup and dropoff)
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
        -- Create a proper surrogate key (use FARM_FINGERPRINT or hash)
        FARM_FINGERPRINT(CAST(datetime_key AS STRING)) AS datetime_sk,
        DATE(datetime_key) AS date_key,
        TIME(datetime_key) AS time_key,
        EXTRACT(YEAR FROM datetime_key) AS year,
        EXTRACT(MONTH FROM datetime_key) AS month,
        EXTRACT(DAY FROM datetime_key) AS day_of_month,
        EXTRACT(DAYOFWEEK FROM datetime_key) AS day_of_week,
        FORMAT_DATE('%A', DATE(datetime_key)) AS day_name, -- e.g., Monday
        EXTRACT(HOUR FROM datetime_key) AS hour_of_day,
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
        END AS time_of_day
    FROM distinct_timestamps
    WHERE datetime_key IS NOT NULL
)
SELECT * FROM datetime_parts