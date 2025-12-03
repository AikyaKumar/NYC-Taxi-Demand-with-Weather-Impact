-- models/staging/stg_weather.sql

SELECT
    CAST(timestamp AS TIMESTAMP) AS weather_timestamp,
    CAST(temperature AS NUMERIC) AS temperature_celsius,
    CAST(rain AS NUMERIC) AS rain_mm,
    CAST(snowfall AS NUMERIC) AS snowfall_mm,
    CAST(precipiation AS NUMERIC) AS precipitation_mm,
    CAST(wind_speed AS NUMERIC) AS wind_speed_kph,
    weather_code,
    CAST(relative_humid AS NUMERIC) AS relative_humidity,
    
    -- Extract the date part for joining
    DATE(timestamp) AS weather_date
    
FROM {{ source('dm2_aikya_raw', 'nyc_weather_raw') }}