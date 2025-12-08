-- models/facts/fct_hourly_weather_impact.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH hourly_trips AS (
    SELECT
        -- Time Keys
        t.pickup_hour AS analysis_hour,
        
        -- Dimension Foreign Keys (Natural Keys for joining)
        t.pickup_location_id,
        w.weather_code,
        
        -- Weather Measures (from stg_weather, aliased as w)
        w.temperature_celsius,
        w.precipitation_mm,
        w.wind_speed_kph,
        
        -- Aggregated Trip Metrics
        COUNT(t.trip_sk) AS trip_count,
        SUM(t.total_amount) AS total_revenue,
        AVG(t.trip_distance) AS avg_trip_distance,
        AVG(DATETIME_DIFF(t.dropoff_timestamp, t.pickup_timestamp, MINUTE)) AS avg_trip_duration,
        SUM(t.tip_amount) AS total_tips,
        
        -- Payment Distribution (Expanded all codes from 0 to 6)
        COUNT(CASE WHEN t.payment_type = 1 THEN 1 END) AS credit_card_trips,
        COUNT(CASE WHEN t.payment_type = 2 THEN 1 END) AS cash_trips,
        COUNT(CASE WHEN t.payment_type = 0 THEN 1 END) AS flex_fare_trips,
        COUNT(CASE WHEN t.payment_type = 3 THEN 1 END) AS no_charge_trips,
        COUNT(CASE WHEN t.payment_type = 4 THEN 1 END) AS dispute_trips,
        COUNT(CASE WHEN t.payment_type = 5 THEN 1 END) AS unknown_payment_trips,
        COUNT(CASE WHEN t.payment_type = 6 THEN 1 END) AS voided_trips,

        -- Vendor Distribution (Using distinct IDs 1, 2, 6, 7)
        COUNT(CASE WHEN t.vendor_id = 1 THEN 1 END) AS cmt_trips,
        COUNT(CASE WHEN t.vendor_id = 2 THEN 1 END) AS curb_trips,
        COUNT(CASE WHEN t.vendor_id = 6 THEN 1 END) AS myle_trips,
        COUNT(CASE WHEN t.vendor_id = 7 THEN 1 END) AS helix_trips
        
    FROM {{ ref('stg_taxi_trips') }} t
    LEFT JOIN {{ ref('stg_weather') }} w
        ON t.pickup_hour = w.weather_timestamp
        
    -- Group by all non-aggregated columns (10 columns)
    GROUP BY 1, 2, 3, 4, 5, 6
),

enriched AS (
    SELECT
        -- Primary Key
        FARM_FINGERPRINT(
            CONCAT(
                CAST(ht.analysis_hour AS STRING),
                '_',
                CAST(ht.pickup_location_id AS STRING)
            )
        ) AS hourly_impact_sk,
        
        -- Dimension Foreign Keys
        DATE(ht.analysis_hour) AS date_key,
        EXTRACT(HOUR FROM ht.analysis_hour) AS hour_key,
        ht.analysis_hour,
        dz.zone_sk, 
        dwc.weather_sk,
        
        -- Weather Measures
        ht.temperature_celsius,
        ht.precipitation_mm,
        ht.wind_speed_kph,
        
        -- Demand & Financial Metrics
        ht.trip_count,
        ht.total_revenue,
        ht.total_tips,
        ht.avg_trip_duration,
        ht.avg_trip_distance,
        
        -- Payment Distribution Metrics
        ht.credit_card_trips,
        ht.cash_trips,
        ht.flex_fare_trips,
        ht.dispute_trips,
        
        -- Vendor Distribution Metrics (Included for mart analysis)
        ht.cmt_trips,
        ht.curb_trips,
        ht.myle_trips,
        ht.helix_trips,
        
        -- Derived Metrics
        SAFE_DIVIDE(ht.credit_card_trips, ht.trip_count) * 100 AS credit_card_percentage,
        SAFE_DIVIDE(ht.total_revenue, ht.trip_count) AS avg_revenue_per_trip,
        
        -- Weather Impact Classification (Using combined weather/temperature logic)
        CASE 
            WHEN ht.precipitation_mm >= 3 THEN 'Heavy Rain/Snow Impact'
            WHEN ht.temperature_celsius < 0 THEN 'Cold Impact'
            WHEN ht.temperature_celsius > 35 THEN 'Heat Impact'
            WHEN dwc.weather_severity IN ('Severe (Heavy Impact)', 'Extreme (Major Disruption)') THEN 'Major Weather Disruption'
            ELSE 'Normal Conditions'
        END AS weather_impact_type
        
    FROM hourly_trips ht
    
    -- Join all dimensions to retrieve their Surrogate Keys
    LEFT JOIN {{ ref('dim_taxi_zones') }} dz ON ht.pickup_location_id = dz.location_id
    LEFT JOIN {{ ref('dim_weather_conditions') }} dwc ON ht.weather_code = dwc.weather_code
)

SELECT * FROM enriched