-- models/dimensions/dim_date.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH date_range AS (
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
    
    -- Standard date parts
    EXTRACT(YEAR FROM date) AS year,
    EXTRACT(QUARTER FROM date) AS quarter,
    EXTRACT(MONTH FROM date) AS month,
    EXTRACT(WEEK FROM date) AS week_of_year,
    EXTRACT(DAY FROM date) AS day_of_month,
    EXTRACT(DAYOFWEEK FROM date) AS day_of_week,
    FORMAT_DATE('%A', date) AS day_name,
    FORMAT_DATE('%B', date) AS month_name,
    FORMAT_DATE('%Y-%m', date) AS year_month,
    
    -- Business flags
    CASE 
        WHEN EXTRACT(DAYOFWEEK FROM date) IN (1, 7) THEN TRUE
        ELSE FALSE
    END AS is_weekend,
    
    -- NYC-specific holidays that affect taxi demand
    CASE 
        WHEN date IN (
            '2025-01-01', '2025-01-16', '2025-02-20', '2025-05-29',
            '2025-07-04', '2025-09-04', '2025-10-09', '2025-11-10',
            '2025-11-23', '2025-12-25'
        ) THEN TRUE
        ELSE FALSE
    END AS is_holiday,
    
    -- Seasonal attributes for weather correlation
    CASE
        WHEN EXTRACT(MONTH FROM date) IN (12, 1, 2) THEN 'Winter'
        WHEN EXTRACT(MONTH FROM date) IN (3, 4, 5) THEN 'Spring'
        WHEN EXTRACT(MONTH FROM date) IN (6, 7, 8) THEN 'Summer'
        ELSE 'Fall'
    END AS season,
    
    -- Weather-specific seasons
    CASE
        WHEN EXTRACT(MONTH FROM date) IN (12, 1, 2) THEN 'Cold Season'
        WHEN EXTRACT(MONTH FROM date) IN (6, 7, 8) THEN 'Hot Season'
        ELSE 'Transition Season'
    END AS temperature_season,
    
    -- Rainy season in NYC (Spring/Fall)
    CASE
        WHEN EXTRACT(MONTH FROM date) IN (3, 4, 5, 9, 10, 11) THEN 'Rainy Season'
        ELSE 'Dry Season'
    END AS precipitation_season,
    
    -- NYC tourist seasons (affects taxi demand)
    CASE
        WHEN EXTRACT(MONTH FROM date) IN (6, 7, 8) THEN 'Peak Tourist'
        WHEN EXTRACT(MONTH FROM date) IN (5, 9) THEN 'Shoulder Tourist'
        ELSE 'Off Tourist'
    END AS tourism_season
    
FROM all_dates