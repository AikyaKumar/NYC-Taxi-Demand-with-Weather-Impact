-- models/facts/fct_zone_route_demand.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH route_trips AS (
    SELECT
        -- Time Key (Hourly grain for maximum detail)
        t.pickup_hour AS analysis_hour,
        
        -- Location Keys (Natural keys from staging)
        t.pickup_location_id,
        t.dropoff_location_id,
        
        -- Aggregated Measures
        COUNT(t.trip_sk) AS route_trip_count,
        SUM(t.total_amount) AS route_total_revenue,
        AVG(t.trip_distance) AS route_avg_distance,
        AVG(t.total_amount) AS route_avg_fare,
        
        -- Specialized metrics for routes
        AVG(DATETIME_DIFF(t.dropoff_timestamp, t.pickup_timestamp, MINUTE)) AS route_avg_duration,
        
        -- Count of disputed/issue trips on this route
        COUNT(CASE WHEN t.payment_type IN (4, 6) THEN 1 END) AS issue_trip_count
        
    FROM {{ ref('stg_taxi_trips') }} t
    GROUP BY 1, 2, 3
)
SELECT
    -- Primary Key
    FARM_FINGERPRINT(
        CONCAT(
            CAST(rt.analysis_hour AS STRING),
            CAST(rt.pickup_location_id AS STRING),
            CAST(rt.dropoff_location_id AS STRING)
        )
    ) AS route_demand_sk,
    
    -- Foreign Keys
    DATE(rt.analysis_hour) AS date_key,
    tod.hour_key,
    dz_pickup.zone_sk AS pickup_zone_sk,
    dz_dropoff.zone_sk AS dropoff_zone_sk,
    
    -- Metrics
    rt.route_trip_count,
    rt.route_total_revenue,
    rt.route_avg_distance,
    rt.route_avg_fare,
    rt.route_avg_duration,
    rt.issue_trip_count,
    
    -- Derived Metrics for analysis
    SAFE_DIVIDE(rt.route_total_revenue, rt.route_trip_count) AS route_avg_revenue_per_trip
    
FROM route_trips rt
-- Join Time Dimensions
LEFT JOIN {{ ref('dim_time_of_day') }} tod ON EXTRACT(HOUR FROM rt.analysis_hour) = tod.hour_key
-- Join to dim_taxi_zones twice for pickup and dropoff
LEFT JOIN {{ ref('dim_taxi_zones') }} dz_pickup ON rt.pickup_location_id = dz_pickup.location_id
LEFT JOIN {{ ref('dim_taxi_zones') }} dz_dropoff ON rt.dropoff_location_id = dz_dropoff.location_id