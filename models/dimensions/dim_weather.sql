-- models/dimensions/dim_weather.sql
-- Translates weather codes and provides the unique context of weather conditions

SELECT
    -- Primary Key: The weather record's unique identifier
    weather_sk,
    
    -- Descriptive Attributes
    timezone,
    weather_code,
    
    -- 1. Descriptive Name: Translates code to readable condition
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
        END AS weather_desc, -- ALIAS 1: Descriptive Name

    -- 2. Business Category: Simplified grouping for analysis
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
    END AS weather_category, -- ALIAS 2: Category

    -- 3. Key Metric Tier: Temperature band for quick filtering
    CASE
        WHEN temperature > 25 THEN 'Hot'
        WHEN temperature BETWEEN 10 AND 25 THEN 'Mild'
        ELSE 'Cold'
    END AS temperature_tier, -- ALIAS 3: Temperature Tier

    -- 4. Visual Flags (Booleans for easy filtering on specific conditions)
    CASE WHEN weather_code IN (51, 53, 55, 61, 63, 65, 66, 67, 80, 81, 82) THEN TRUE ELSE FALSE END AS is_rainy_flag, -- ALIAS 4: Rainy Flag
    CASE WHEN weather_code IN (56, 57, 66, 67, 71, 73, 75, 77, 85, 86) THEN TRUE ELSE FALSE END AS is_snowy_flag,   -- ALIAS 5: Snowy Flag
    CASE WHEN weather_code IN (95, 96, 99) THEN TRUE ELSE FALSE END AS is_stormy_flag   -- ALIAS 6: Stormy Flag

-- Pull the necessary data from the staging model
-- We need temperature_celsius from staging to calculate temperature_tier
FROM {{ ref('stg_weather') }}