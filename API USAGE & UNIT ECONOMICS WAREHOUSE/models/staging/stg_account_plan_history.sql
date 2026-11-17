select
    trim(account_plan_history_id)              as account_plan_history_id,
    trim(account_id)                           as account_id,
    trim(plan_id)                              as plan_id,
    cast(valid_from as timestamptz)            as valid_from,
    cast(valid_to as timestamptz)              as valid_to,
    cast(source_updated_at as timestamptz)     as source_updated_at
from {{ source('raw', 'account_plan_history') }}
