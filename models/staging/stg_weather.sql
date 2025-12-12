-- models/staging/stg_nyc_weather.sql

select

    -- Primary Key: Generate a unique ID based on location and time
    MD5(
        CAST(latitude AS STRING) ||
        CAST(longitude AS STRING) ||
        CAST(hourly_timestamp AS STRING)
    ) as weather_sk,

    -- Location Details (used for joining)
    cast(latitude as numeric) as latitude,
    cast(longitude as numeric) as longitude,
    timezone,

    -- Time Details
    cast(hourly_timestamp as timestamp) as weather_timestamp,

    -- Weather Metrics
    cast(weather_code as int) as weather_code,
    cast(temperature_2m as numeric) as temperature,
    cast(relative_humidity_2m as numeric) as relative_humidity,
    cast(precipitation as numeric) as precipitation,
    cloudcover,
    cast(windspeed_10m as numeric) as windspeed,
    cast(is_day as int) as is_day,

-- Direct reference to the BigQuery table path:
from `dm2-project-479611.dm2_aikya.nyc_weather_raw`