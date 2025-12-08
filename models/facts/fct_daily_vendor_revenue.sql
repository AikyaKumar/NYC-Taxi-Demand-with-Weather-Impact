-- models/facts/fct_daily_vendor_revenue.sql
{{ config(materialized='table', schema='dm2_aikya_analytics') }}

WITH daily_trips AS (
    SELECT
        -- Time Keys
        DATE(t.pickup_timestamp) AS analysis_date,
        
        -- Dimension Foreign Keys (Natural Keys for joining to Dim)
        t.vendor_id,
        
        -- Aggregated Measures
        COUNT(t.trip_sk) AS daily_trip_count,
        SUM(t.total_amount) AS daily_total_revenue,
        AVG(t.trip_distance) AS daily_avg_trip_distance,
        SUM(t.tip_amount) AS daily_total_tips,
        
        -- Payment Segmentation for share analysis (All major categories)
        SUM(CASE WHEN t.payment_type = 1 THEN t.total_amount ELSE 0 END) AS credit_card_revenue,
        SUM(CASE WHEN t.payment_type = 2 THEN t.total_amount ELSE 0 END) AS cash_revenue,
        SUM(CASE WHEN t.payment_type = 0 THEN t.total_amount ELSE 0 END) AS flex_fare_revenue,
        
        -- Tracking Non-Revenue/Issue trips
        COUNT(CASE WHEN t.payment_type IN (3, 4, 5, 6) THEN 1 END) AS non_revenue_trip_count
        
    FROM {{ ref('stg_taxi_trips') }} t
    GROUP BY 1, 2
),

enriched AS (
    SELECT
        -- Primary Key
        FARM_FINGERPRINT(CONCAT(CAST(dt.analysis_date AS STRING), '_', CAST(dt.vendor_id AS STRING))) AS daily_vendor_sk,
        
        -- Foreign Keys (FKs)
        dt.analysis_date AS date_key,
        dd.year, -- Attribute from dim_date for easy filtering
        dv.vendor_sk,
        
        -- Metrics
        dt.daily_trip_count,
        dt.daily_total_revenue,
        dt.daily_avg_trip_distance,
        dt.daily_total_tips,
        dt.non_revenue_trip_count,

        -- Revenue Segmentation
        dt.credit_card_revenue,
        dt.cash_revenue,
        dt.flex_fare_revenue,
        
        -- Derived Metrics
        SAFE_DIVIDE(dt.daily_total_revenue, dt.daily_trip_count) AS daily_avg_revenue_per_trip,
        SAFE_DIVIDE(dt.daily_total_tips, dt.daily_total_revenue) * 100 AS daily_tip_percentage
        
    FROM daily_trips dt
    LEFT JOIN {{ ref('dim_vendor') }} dv ON dt.vendor_id = dv.vendor_id
    LEFT JOIN {{ ref('dim_date') }} dd ON dt.analysis_date = dd.date_key
)

SELECT * FROM enriched