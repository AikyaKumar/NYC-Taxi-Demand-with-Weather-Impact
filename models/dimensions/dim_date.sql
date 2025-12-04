-- models/dimensions/dim_date.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH date_range AS (
    -- Generate a date range from your data
    SELECT 
        MIN(DATE(pickup_timestamp)) as min_date,
        MAX(DATE(pickup_timestamp)) as max_date
    FROM {{ ref('stg_taxi_trips') }}
),
all_dates AS (
    SELECT date
    FROM date_range,
    UNNEST(GENERATE_DATE_ARRAY(min_date, max_date, INTERVAL 1 DAY)) as date
)
SELECT
    date AS date_key,
    EXTRACT(YEAR FROM date) AS year,
    EXTRACT(QUARTER FROM date) AS quarter,
    EXTRACT(MONTH FROM date) AS month,
    EXTRACT(WEEK FROM date) AS week_of_year,
    EXTRACT(DAY FROM date) AS day_of_month,
    EXTRACT(DAYOFWEEK FROM date) AS day_of_week,
    FORMAT_DATE('%A', date) AS day_name,
    FORMAT_DATE('%B', date) AS month_name,
    CASE 
        WHEN EXTRACT(DAYOFWEEK FROM date) IN (1, 7) THEN TRUE
        ELSE FALSE
    END AS is_weekend,
    CASE 
        WHEN date IN ('2023-12-25', '2024-01-01') THEN TRUE  -- Add more holidays
        ELSE FALSE
    END AS is_holiday,
    CASE
        WHEN EXTRACT(MONTH FROM date) IN (12, 1, 2) THEN 'Winter'
        WHEN EXTRACT(MONTH FROM date) IN (3, 4, 5) THEN 'Spring'
        WHEN EXTRACT(MONTH FROM date) IN (6, 7, 8) THEN 'Summer'
        ELSE 'Fall'
    END AS season
FROM all_dates