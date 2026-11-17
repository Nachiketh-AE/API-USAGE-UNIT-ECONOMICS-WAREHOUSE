select
    trim(account_id)                           as account_id,
    trim(account_name)                         as account_name,
    cast(account_created_at as timestamptz)    as account_created_at,
    lower(trim(account_status))                as account_status,
    lower(trim(account_segment))               as account_segment,
    upper(trim(country_code))                  as country_code,
    cast(source_updated_at as timestamptz)     as source_updated_at
from {{ source('raw', 'accounts') }}
