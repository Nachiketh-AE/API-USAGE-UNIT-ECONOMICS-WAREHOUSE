select
    trim(customer_pricing_version_id)          as customer_pricing_version_id,
    trim(model_id)                             as model_id,
    trim(plan_id)                              as plan_id,
    lower(trim(usage_component))               as usage_component,
    lower(trim(unit_of_measure))               as unit_of_measure,
    cast(price_per_million_tokens as numeric(18,6)) as price_per_million_tokens,
    upper(trim(currency))                      as currency,
    cast(valid_from as timestamptz)            as valid_from,
    cast(valid_to as timestamptz)              as valid_to,
    cast(source_updated_at as timestamptz)     as source_updated_at
from {{ source('raw', 'customer_pricing_schedules') }}
