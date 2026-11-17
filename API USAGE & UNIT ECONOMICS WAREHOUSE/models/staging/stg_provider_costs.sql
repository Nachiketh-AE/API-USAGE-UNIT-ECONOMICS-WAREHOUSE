select
    trim(provider_cost_version_id)             as provider_cost_version_id,
    trim(provider_id)                          as provider_id,
    trim(model_id)                             as model_id,
    lower(trim(usage_component))               as usage_component,
    lower(trim(unit_of_measure))               as unit_of_measure,
    cast(cost_per_million_tokens as numeric(18,6)) as cost_per_million_tokens,
    upper(trim(currency))                      as currency,
    cast(valid_from as timestamptz)            as valid_from,
    cast(valid_to as timestamptz)              as valid_to,
    cast(source_updated_at as timestamptz)     as source_updated_at
from {{ source('raw', 'provider_cost_schedules') }}
