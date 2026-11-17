select
    trim(plan_id)                              as plan_id,
    trim(plan_name)                            as plan_name,
    trim(plan_description)                     as plan_description,
    cast(is_free_plan as boolean)              as is_free_plan,
    cast(is_active as boolean)                 as is_active,
    cast(source_updated_at as timestamptz)     as source_updated_at
from {{ source('raw', 'plans') }}
