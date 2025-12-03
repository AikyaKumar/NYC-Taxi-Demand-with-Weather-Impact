-- models/staging/stg_weather.sql

SELECT
    CAST(timestamp AS TIMESTAMP) AS weather_timestamp,
    CAST(temperature_2m AS NUMERIC) AS temperature_2m,,
    CAST(rain AS NUMERIC) AS rain_mm,
    CAST(snowfall AS NUMERIC) AS snowfall_mm,
    CAST(precipitation AS NUMERIC) AS precipitation_mm,
    CAST(wind_speed_10m AS NUMERIC) AS wind_speed_kph,
    CAST(weather_code AS INT64) AS weather_code,
    CAST(relative_humidity_2m AS NUMERIC) AS relative_humidity_2m,
    CAST(is_day AS INT64) AS is_day,
    DATETIME_TRUNC(weather_timestamp, HOUR) AS weather_hour,
    
    -- Extract the date part for joining
    DATE(timestamp) AS weather_date
    
FROM {{ source('dm2_aikya_raw', 'nyc_weather_raw') }}