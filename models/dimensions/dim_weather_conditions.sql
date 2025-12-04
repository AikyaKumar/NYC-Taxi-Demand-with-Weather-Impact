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
        
        -- Human-readable descriptions
        CASE weather_code
            WHEN 0 THEN 'Clear Sky'
            WHEN 1 THEN 'Mainly Clear'
            WHEN 2 THEN 'Partly Cloudy'
            WHEN 3 THEN 'Overcast'
            WHEN 45 THEN 'Fog'
            WHEN 48 THEN 'Rime Fog'
            WHEN 51 THEN 'Light Drizzle'
            WHEN 53 THEN 'Moderate Drizzle'
            WHEN 55 THEN 'Heavy Drizzle'
            WHEN 61 THEN 'Light Rain'
            WHEN 63 THEN 'Moderate Rain'
            WHEN 65 THEN 'Heavy Rain'
            WHEN 71 THEN 'Light Snow'
            WHEN 73 THEN 'Moderate Snow'
            WHEN 75 THEN 'Heavy Snow'
            WHEN 80 THEN 'Light Rain Showers'
            WHEN 81 THEN 'Moderate Rain Showers'
            WHEN 82 THEN 'Violent Rain Showers'
            ELSE 'Unknown'
        END AS weather_description,
        
        -- Business categories for analysis
        CASE 
            WHEN weather_code IN (0, 1, 2, 3) THEN 'Clear/Cloudy'
            WHEN weather_code IN (45, 48) THEN 'Fog'
            WHEN weather_code IN (51, 53, 55, 56, 57) THEN 'Drizzle'
            WHEN weather_code IN (61, 63, 65, 66, 67, 80, 81, 82) THEN 'Rain'
            WHEN weather_code IN (71, 73, 75, 77, 85, 86) THEN 'Snow'
            WHEN weather_code IN (95, 96, 99) THEN 'Thunderstorm'
            ELSE 'Other'
        END AS weather_category,
        
        -- Severity classification
        CASE
            WHEN weather_code IN (0, 1, 2) THEN 'Good'
            WHEN weather_code IN (3, 45, 48, 51, 56, 61, 66, 71, 77, 80, 85) THEN 'Fair'
            WHEN weather_code IN (53, 55, 63, 65, 67, 73, 75, 81, 86, 95) THEN 'Poor'
            WHEN weather_code IN (82, 96, 99) THEN 'Severe'
            ELSE 'Unknown'
        END AS weather_severity,
        
        -- Visual flags
        CASE WHEN weather_code IN (61, 63, 65, 80, 81, 82) THEN TRUE ELSE FALSE END AS is_rainy,
        CASE WHEN weather_code IN (71, 73, 75, 85, 86) THEN TRUE ELSE FALSE END AS is_snowy,
        CASE WHEN weather_code IN (95, 96, 99) THEN TRUE ELSE FALSE END AS is_stormy
        
    FROM weather_codes
)
SELECT * FROM weather_details