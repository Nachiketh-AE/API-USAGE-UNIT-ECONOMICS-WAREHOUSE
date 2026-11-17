-- Grain: one account (static MVP dimension).
select
    {{ surrogate_key(['account_id']) }} as account_key,
    account_id,
    account_name,
    account_created_at,
    account_status,
    account_segment,
    country_code,
    source_updated_at
from {{ ref('stg_accounts') }}
