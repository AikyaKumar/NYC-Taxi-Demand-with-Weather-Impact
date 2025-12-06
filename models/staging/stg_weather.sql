{{ config(materialized='view', schema='stg') }}

SELECT
    CAST(hourly_timestamp AS TIMESTAMP) AS weather_timestamp,
    
    CAST(temperature_2m AS NUMERIC) AS temperature_celsius,
    CAST(relative_humidity_2m AS NUMERIC) AS relative_humidity,
    
    -- ONLY precipitation is available from the Open-Meteo hourly vars
    CAST(precipitation AS NUMERIC) AS precipitation_mm,
    
    -- These columns ARE available and must be included
    CAST(cloudcover AS INTEGER) AS cloudcover_pct,
    CAST(windspeed_10m AS NUMERIC) AS wind_speed_kph, 
    
    -- weather_code is requested from the API (HOURLY_VARS) but not defined in your PySpark TARGET_SCHEMA.
    -- If the PySpark job does not land 'weather_code', this will fail. We'll proceed assuming the PySpark schema is definitive (no weather_code).
    
    DATE(hourly_timestamp) AS weather_date

FROM {{ source('dm2_aikya', 'nyc_weather_raw') }}
WHERE hourly_timestamp IS NOT NULL