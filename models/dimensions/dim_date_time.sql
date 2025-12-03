-- models/dimensions/dim_date_time.sql

WITH distinct_timestamps AS (
    -- Combine all relevant timestamps (pickup and dropoff)
    SELECT pickup_timestamp AS datetime_key FROM {{ ref('stg_taxi_trips') }}
    UNION DISTINCT
    SELECT dropoff_timestamp FROM {{ ref('stg_taxi_trips') }}
),
datetime_parts AS (
    SELECT
        datetime_key,
        DATE(datetime_key) AS date_key,
        TIME(datetime_key) AS time_key,
        EXTRACT(YEAR FROM datetime_key) AS year,
        EXTRACT(MONTH FROM datetime_key) AS month,
        EXTRACT(DAY FROM datetime_key) AS day_of_month,
        FORMAT_DATE('%A', DATE(datetime_key)) AS day_name, -- e.g., Monday
        EXTRACT(HOUR FROM datetime_key) AS hour_of_day,
        CASE
            WHEN EXTRACT(HOUR FROM datetime_key) BETWEEN 6 AND 9 THEN 'Morning Rush'
            WHEN EXTRACT(HOUR FROM datetime_key) BETWEEN 16 AND 19 THEN 'Evening Rush'
            ELSE 'Off-Peak'
        END AS peak_time_band
    FROM distinct_timestamps
)
SELECT * FROM datetime_parts