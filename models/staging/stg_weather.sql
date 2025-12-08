{{ config(materialized='view', schema='stg') }}

SELECT
    -- MAPPING & CASTING
    CAST(hourly_timestamp AS TIMESTAMP) AS weather_timestamp,
    DATE(hourly_timestamp) AS weather_date,
    
    -- Sourced from the image/raw schema, defined in the target staging schema
    CAST(weather_code AS INTEGER) AS weather_code,
    
    -- Sourced from the image/raw schema, defined in the target staging schema
    CAST(temperature_2m AS NUMERIC) AS temperature_celsius,
    
    -- Sourced from the image/raw schema, defined in the target staging schema
    CAST(precipitation AS NUMERIC) AS precipitation_mm,
    
    -- Sourced from the image/raw schema, defined in the target staging schema
    CAST(windspeed_10m AS NUMERIC) AS wind_speed_kph, 
    
    -- Sourced from the image/raw schema, defined in the target staging schema
    CAST(relative_humidity_2m AS NUMERIC) AS relative_humidity,
    
    -- Sourced from the image/raw schema, defined in the target staging schema
    CAST(is_day AS INTEGER) AS is_day,

    -- Retain cloudcover for completeness, although not in the target staging schema provided
    CAST(cloudcover AS INTEGER) AS cloudcover_pct,
    
    -- Keeping source columns for potential future use or debugging
    latitude,
    longitude,
    timezone

FROM `dm2-project-479611`.`dm2_aikya`.`nyc_weather_raw`
WHERE hourly_timestamp IS NOT NULL