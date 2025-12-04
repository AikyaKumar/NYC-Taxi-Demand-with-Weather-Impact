-- models/dimensions/dim_taxi_zones.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH zones AS (
    SELECT
        location_id,
        FARM_FINGERPRINT(CONCAT(CAST(location_id AS STRING), borough, zone_name)) AS zone_sk,
        borough,
        zone_name,
        service_zone,
        
        -- Weather Vulnerability Attributes
        CASE 
            WHEN borough IN ('Manhattan', 'Brooklyn') THEN 'High-Density Urban'
            WHEN borough IN ('Queens', 'Bronx') THEN 'Medium-Density Urban'
            WHEN borough = 'Staten Island' THEN 'Low-Density Suburban'
            WHEN service_zone LIKE '%Airport%' THEN 'Airport Zone'
            ELSE 'Other'
        END AS urban_density_category,
        
        CASE 
            WHEN service_zone LIKE '%Airport%' THEN TRUE
            ELSE FALSE
        END AS is_airport_zone,
        
        CASE 
            WHEN borough = 'Manhattan' THEN 'Core Business District'
            WHEN borough IN ('Brooklyn', 'Queens') THEN 'Outer Borough'
            ELSE 'Peripheral'
        END AS business_zone_category,
        
        -- Estimated weather impact (based on zone characteristics)
        CASE
            WHEN service_zone LIKE '%Airport%' THEN 'High - Travel Disruptions'
            WHEN borough = 'Manhattan' THEN 'Medium - High Alternatives'
            WHEN borough IN ('Brooklyn', 'Queens') THEN 'Medium - Moderate Alternatives'
            ELSE 'Low - Limited Alternatives'
        END AS estimated_weather_impact
        
    FROM {{ ref('stg_taxi_zones') }}
    WHERE location_id IS NOT NULL
      AND borough IS NOT NULL
      AND zone_name IS NOT NULL
)
SELECT * FROM zones