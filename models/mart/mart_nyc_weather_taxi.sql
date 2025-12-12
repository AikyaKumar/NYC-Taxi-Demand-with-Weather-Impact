-- models/marts/mart_nyc_taxi_analysis.sql

SELECT
    -- 1. TRIP & VENDOR KEYS/ATTRIBUTES (The WHO)
    f.trip_sk,
    dv.vendor_group,
    dv.vendor_name,
    f.passenger_count,            -- REQUIRED (2)
    f.trip_distance,              -- REQUIRED (3)
    f.store_and_fwd_flag,         -- REQUIRED (5)
    
    -- 2. FINANCIAL/RATE KEYS
    f.ratecode_sk,                -- REQUIRED (4)
    f.payment_type_sk,            -- REQUIRED (8)
    
    -- 3. TIME CONTEXT (The WHEN)
    f.pickup_date_time_sk,
    dd.date_pk,
    dd.year,
    dd.quarter_of_year,
    dd.month_of_year,
    dd.week_of_year,
    dd.day_of_month,
    dd.day_name,
    dd.month_name,
    dd.hour_of_day,
    dd.is_weekend,
    dd.is_holiday,
    dd.peak_hour,
    dd.season,
    
    -- 4. LOCATION CONTEXT (The WHERE)
    -- Raw IDs (still useful for filtering)
    f.pickup_location_sk,         -- REQUIRED (6)
    f.dropoff_location_sk,        -- REQUIRED (7)
    -- Joined Details
    dl_pu.borough AS pickup_borough,
    dl_pu.zone_name AS pickup_zone_name,
    dl_do.borough AS dropoff_borough,
    dl_do.zone_name AS dropoff_zone_name,
    dl_pu.service_zone AS pickup_service_zone,
    dl_do.service_zone AS dropoff_service_zone,
    
    -- 5. WEATHER CONTEXT (The CONDITION)
    f.weather_sk,
    dw.weather_desc,
    dw.weather_category,
    dw.is_rainy_flag,
    dw.is_snowy_flag,
    dw.is_stormy_flag,
    dw.temperature_tier,
    
    -- 6. CALCULATED METRICS & FINANCIALS
    f.trip_duration_minutes,
    
    -- All Financial Components (REQUIRED 9)
    f.fare_amount,
    f.extra_amount,
    f.mta_tax_amount ,
    f.tip_amount,
    f.tolls_amount,
    f.improvement_surcharge,
    f.congestion_surcharge,
    f.airport_fee,
    f.total_amount 

FROM {{ ref('fact_taxi_trips') }} f
LEFT JOIN {{ ref('dim_vendor') }} dv
    ON f.vendor_sk = dv.vendor_sk
LEFT JOIN {{ ref('dim_date_time') }} dd
    ON f.pickup_date_time_sk = dd.date_time_sk
LEFT JOIN {{ ref('dim_locations') }} dl_pu
    ON f.pickup_location_sk = dl_pu.location_sk
LEFT JOIN {{ ref('dim_locations') }} dl_do
    ON f.dropoff_location_sk = dl_do.location_sk
LEFT JOIN {{ ref('dim_weather') }} dw
    ON f.weather_sk = dw.weather_sk