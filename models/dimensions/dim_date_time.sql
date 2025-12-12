-- models/dimensions/dim_date_time.sql
-- Provides comprehensive time and calendar context for every trip timestamp.
-- Materialized as a TABLE in schema dm2_analytics

with trip_timestamps as (
    -- Step 1: Get the unique hour of every trip from the staging table
    select distinct timestamp_trunc(pickup_datetime, HOUR) as pickup_hour_timestamp
    from {{ ref('stg_taxi_trips') }}
    where pickup_datetime is not null
),

add_date_parts as (
    select
        -- PRIMARY KEY (SK): The full hour timestamp is the most granular key
        pickup_hour_timestamp as date_time_sk,
        
        -- Use the DATE part for calendar context attributes
        cast(extract(date from pickup_hour_timestamp) as date) as date_pk,

        -- 1. Standard Date Parts (matching your requested parts)
        extract(year from pickup_hour_timestamp) as year,
        extract(quarter from pickup_hour_timestamp) as quarter_of_year,
        extract(month from pickup_hour_timestamp) as month_of_year,
        extract(week from pickup_hour_timestamp) as week_of_year,
        extract(day from pickup_hour_timestamp) as day_of_month,
        
        -- Day/Month Names (for dashboard labels)
        format_date('%A', date(pickup_hour_timestamp)) as day_name, -- e.g., Monday
        format_date('%B', date(pickup_hour_timestamp)) as month_name,       -- e.g., March
        
        -- Time Part
        extract(hour from pickup_hour_timestamp) as hour_of_day,

        -- 2. Business Flags
        case
            when extract(dayofweek from pickup_hour_timestamp) in (1, 7) then 'Yes' -- 1=Sunday, 7=Saturday
            else 'No'
        end as is_weekend,

        -- 3. Peak Hour Buckets
        case
            when extract(hour from pickup_hour_timestamp) between 16 and 20 then 'Evening Peak'
            when extract(hour from pickup_hour_timestamp) between 6 and 10 then 'Morning Peak'
            else 'Off-Peak'
        end as peak_hour,
        
        -- 4. NYC Seasons
        case
            when extract(month from pickup_hour_timestamp) in (12, 1, 2) then 'Winter'
            when extract(month from pickup_hour_timestamp) in (3, 4, 5) then 'Spring'
            when extract(month from pickup_hour_timestamp) in (6, 7, 8) then 'Summer'
            else 'Autumn' -- 9, 10, 11
        end as season

    from trip_timestamps
)

-- CTE to add the Holiday Flag based on your hardcoded list
select
    *, -- Selects all the attributes from the CTE above

    case
        when date_pk IN (
            -- 2025 US Federal Holidays (Simplified List)
            '2025-01-01', '2025-01-20', '2025-02-17', '2025-05-26', '2025-06-19', 
            '2025-07-04', '2025-09-01', '2025-10-13', '2025-11-11', '2025-11-27', 
            '2025-12-25',
            -- NYC-Specific Events
            '2025-03-17', '2025-04-20', '2025-05-04', '2025-09-07', '2025-12-31'
        ) THEN 'Yes'
        ELSE 'No'
    END AS is_holiday
    
from add_date_parts