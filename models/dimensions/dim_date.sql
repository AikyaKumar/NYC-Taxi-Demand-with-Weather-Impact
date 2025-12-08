-- models/dimensions/dim_date.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH date_range AS (
    SELECT 
        -- Determine the minimum start date from EITHER taxi or weather data
        MIN(DATE(latest_data.min_timestamp)) as min_date,
        -- Determine the maximum end date from EITHER taxi or weather data
        MAX(DATE(latest_data.max_timestamp)) as max_date
    FROM (
        SELECT MIN(pickup_timestamp) AS min_timestamp, MAX(pickup_timestamp) AS max_timestamp FROM {{ ref('stg_taxi_trips') }}
        UNION ALL
        SELECT MIN(weather_timestamp) AS min_timestamp, MAX(weather_timestamp) AS max_timestamp FROM {{ ref('stg_weather') }}
    ) latest_data
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
    -- ... (keep all standard date parts: quarter, month, day, etc.)
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
    
    -- NYC-specific holidays
    CASE 
        WHEN date IN (
        -- 2025 US Federal Holidays
        '2025-01-01',  -- New Year's Day
        '2025-01-20',  -- Martin Luther King Jr. Day (3rd Monday)
        '2025-02-17',  -- Presidents' Day (3rd Monday)
        '2025-05-26',  -- Memorial Day (last Monday)
        '2025-06-19',  -- Juneteenth
        '2025-07-04',  -- Independence Day
        '2025-09-01',  -- Labor Day (1st Monday)
        '2025-10-13',  -- Columbus Day (2nd Monday)
        '2025-11-11',  -- Veterans Day
        '2025-11-27',  -- Thanksgiving (4th Thursday)
        '2025-12-25',  -- Christmas Day
        
        -- NYC-Specific Events (major impact on taxi demand)
        '2025-03-17',  -- St. Patrick's Day (parade - huge taxi demand)
        '2025-04-20',  -- Easter Sunday
        '2025-05-04',  -- NYC Marathon Sunday (if in Nov, adjust)
        '2025-09-07',  -- US Open Finals weekend
        '2025-12-31'   -- New Year's Eve
        ) THEN TRUE
        ELSE FALSE
    END AS is_holiday,
    
    -- STANDARD SEASONAL attributes (based on calendar month)
    CASE
        WHEN EXTRACT(MONTH FROM date) IN (12, 1, 2) THEN 'Winter'
        WHEN EXTRACT(MONTH FROM date) IN (3, 4, 5) THEN 'Spring'
        WHEN EXTRACT(MONTH FROM date) IN (6, 7, 8) THEN 'Summer'
        ELSE 'Autumn'
    END AS season,
    
    -- TOURISM SEASON is acceptable to define here as it's calendar-based
    CASE
        WHEN EXTRACT(MONTH FROM date) IN (6, 7, 8) THEN 'Peak Tourist'
        WHEN EXTRACT(MONTH FROM date) IN (5, 9) THEN 'Shoulder Tourist'
        ELSE 'Off Tourist'
    END AS tourism_season
    
    -- REMOVED: temperature_season and precipitation_season
    -- REASON: These classifications (Cold/Hot/Rainy/Dry) are based on *observed weather*
    -- and must be derived in the Fact Table by aggregating the weather dimension data.
    
FROM all_dates