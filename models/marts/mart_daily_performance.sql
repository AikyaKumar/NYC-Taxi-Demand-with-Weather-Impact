-- models/marts/mart_daily_performance.sql

SELECT
    CAST(t.weather_date AS DATE) AS trip_day,
    
    COUNT(t.trip_sk) AS total_trips,
    SUM(t.passenger_count) AS total_passengers,
    SUM(t.trip_distance) AS total_miles,
    SUM(t.total_amount) AS total_revenue,
    
    AVG(t.trip_duration_minutes) AS avg_trip_duration_minutes,
    
    -- Weather details for that day
    AVG(w.temperature_celsius) AS avg_daily_temp_celsius,
    SUM(w.rain_mm) AS total_daily_rain_mm
    
FROM {{ ref('fct_taxi_trips') }} t
INNER JOIN {{ ref('stg_weather') }} w -- Join back to stg_weather for aggregation
    ON t.weather_date = w.weather_date

GROUP BY 1
ORDER BY 1 DESC