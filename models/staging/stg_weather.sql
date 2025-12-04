{{ config(materialized='view', schema='stg') }}

SELECT
    CAST(timestamp AS TIMESTAMP) AS weather_timestamp,
    DATE(timestamp) AS weather_date,
    CAST(temperature_2m AS NUMERIC) AS temperature_celsius,  -- Changed to match YAML
    CAST(rain AS NUMERIC) AS rain_mm,
    CAST(snowfall AS NUMERIC) AS snowfall_mm,
    CAST(precipitation AS NUMERIC) AS precipitation_mm,
    CAST(wind_speed_10m AS NUMERIC) AS wind_speed_kph,
    CAST(relative_humidity_2m AS NUMERIC) AS relative_humidity,
    CAST(weather_code AS INT64) AS weather_code,
    CAST(is_day AS INT64) AS is_day
FROM {{ source('dm2_aikya', 'nyc_weather_raw') }}
WHERE timestamp IS NOT NULL