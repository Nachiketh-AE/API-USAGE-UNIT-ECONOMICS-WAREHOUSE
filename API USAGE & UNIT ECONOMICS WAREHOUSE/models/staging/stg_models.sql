select
    trim(model_id)                             as model_id,
    trim(model_name)                           as model_name,
    lower(trim(model_family))                  as model_family,
    trim(provider_id)                          as provider_id,
    trim(provider_name)                        as provider_name,
    lower(trim(model_status))                  as model_status,
    lower(trim(input_unit))                    as input_unit,
    lower(trim(output_unit))                   as output_unit,
    cast(model_created_at as timestamptz)      as model_created_at,
    cast(retired_at as timestamptz)            as retired_at,
    cast(source_updated_at as timestamptz)     as source_updated_at
from {{ source('raw', 'models') }}
