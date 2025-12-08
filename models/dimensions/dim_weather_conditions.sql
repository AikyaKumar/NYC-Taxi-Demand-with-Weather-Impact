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
        
        -- Human-readable descriptions (Expanded WMO codes)
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
            WHEN 56 THEN 'Light Freezing Drizzle'
            WHEN 57 THEN 'Heavy Freezing Drizzle'
            WHEN 61 THEN 'Light Rain'
            WHEN 63 THEN 'Moderate Rain'
            WHEN 65 THEN 'Heavy Rain'
            WHEN 66 THEN 'Light Freezing Rain'
            WHEN 67 THEN 'Heavy Freezing Rain'
            WHEN 71 THEN 'Light Snow'
            WHEN 73 THEN 'Moderate Snow'
            WHEN 75 THEN 'Heavy Snow'
            WHEN 77 THEN 'Snow Grains'
            WHEN 80 THEN 'Light Rain Showers'
            WHEN 81 THEN 'Moderate Rain Showers'
            WHEN 82 THEN 'Violent Rain Showers'
            WHEN 85 THEN 'Light Snow Showers'
            WHEN 86 THEN 'Heavy Snow Showers'
            WHEN 95 THEN 'Thunderstorm (Slight/Moderate)'
            WHEN 96 THEN 'Thunderstorm with Slight Hail'
            WHEN 99 THEN 'Thunderstorm with Heavy Hail'
            ELSE 'Unknown'
        END AS weather_description,
        
        -- Business categories for analysis (Simplified grouping)
        CASE 
            WHEN weather_code IN (0, 1, 2) THEN 'Clear/Partly Cloudy'
            WHEN weather_code = 3 THEN 'Overcast'
            WHEN weather_code IN (45, 48) THEN 'Fog'
            WHEN weather_code IN (51, 53, 55, 56, 57) THEN 'Drizzle/Freezing Drizzle'
            WHEN weather_code IN (61, 63, 65, 66, 67) THEN 'Continuous Rain/Freezing Rain'
            WHEN weather_code IN (80, 81, 82) THEN 'Rain Showers'
            WHEN weather_code IN (71, 73, 75, 77) THEN 'Continuous Snowfall'
            WHEN weather_code IN (85, 86) THEN 'Snow Showers'
            WHEN weather_code IN (95, 96, 99) THEN 'Thunderstorm'
            ELSE 'Other/Unclassified'
        END AS weather_category,
        
        -- Severity classification (Based on impact to travel/driving conditions)
        CASE
            WHEN weather_code IN (0, 1, 2) THEN 'Good (No Impact)'
            WHEN weather_code IN (3, 51, 61, 71, 80) THEN 'Fair (Light Impact)'
            WHEN weather_code IN (45, 48, 53, 56, 73, 81, 85) THEN 'Poor (Moderate Impact)'
            WHEN weather_code IN (55, 57, 63, 66, 75, 77, 86) THEN 'Severe (Heavy Impact)'
            WHEN weather_code IN (65, 67, 82, 95, 96, 99) THEN 'Extreme (Major Disruption)'
            ELSE 'Unknown'
        END AS weather_severity,
        
        -- Visual flags (TRUE/FALSE)
        CASE WHEN weather_code IN (51, 53, 55, 61, 63, 65, 66, 67, 80, 81, 82) THEN TRUE ELSE FALSE END AS is_rainy,
        CASE WHEN weather_code IN (56, 57, 66, 67, 71, 73, 75, 77, 85, 86) THEN TRUE ELSE FALSE END AS is_snowy,
        CASE WHEN weather_code IN (95, 96, 99) THEN TRUE ELSE FALSE END AS is_stormy
        
    FROM weather_codes
)
SELECT * FROM weather_details