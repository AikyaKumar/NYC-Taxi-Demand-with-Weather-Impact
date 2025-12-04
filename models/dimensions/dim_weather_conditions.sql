-- models/dimensions/dim_weather_conditions.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH weather_codes AS (
    SELECT DISTINCT weather_code
    FROM {{ ref('stg_weather') }}
    WHERE weather_code IS NOT NULL
),
weather_details AS (
    SELECT
        weather_code,
        FARM_FINGERPRINT(CAST(weather_code AS STRING)) AS weather_sk,
        CASE weather_code
            WHEN 0 THEN 'Clear Sky'
            WHEN 1 THEN 'Mainly Clear'
            WHEN 2 THEN 'Partly Cloudy'
            WHEN 3 THEN 'Overcast'
            WHEN 45 THEN 'Fog'
            WHEN 48 THEN 'Depositing Rime Fog'
            WHEN 51 THEN 'Light Drizzle'
            WHEN 61 THEN 'Light Rain'
            WHEN 80 THEN 'Light Rain Showers'
            -- Add more codes as needed
            ELSE 'Unknown'
        END AS weather_description,
        CASE 
            WHEN weather_code IN (0, 1, 2, 3) THEN 'Clear/Cloudy'
            WHEN weather_code IN (45, 48) THEN 'Fog'
            WHEN weather_code IN (51, 61, 80) THEN 'Rain'
            ELSE 'Other'
        END AS weather_category
    FROM weather_codes
)
SELECT * FROM weather_details