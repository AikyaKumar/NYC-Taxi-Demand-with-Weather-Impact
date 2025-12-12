-- models/dimensions/dim_vendors.sql
-- Maps VendorID to a business name and your custom persona group (CMT/Curb).

select
    cast(vendor_id as int) as vendor_sk,  -- Primary Key (using the natural key)

    -- Case statement to translate the raw ID to the business name
    case vendor_id
        when 1 then 'Creative Mobile Technologies, LLC'
        when 2 then 'Curb Mobility, LLC'
        when 4 then 'Myle Technologies Inc'
        when 6 then 'Helix'
        else 'Unknown'
    end as vendor_name,

    -- Case statement to create your custom persona groups
    case vendor_id
        when 1 then 'CMT/MYLE Group'
        when 4 then 'CMT/MYLE Group'
        when 2 then 'CURB/HELIX Group'
        when 6 then 'CURB/HELIX Group'
        else 'Unknown'
    end as vendor_group

from {{ ref('stg_taxi_trips') }}
group by 1, 2, 3 -- Group by all columns since they are descriptive attributes