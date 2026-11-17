{{ config(
    materialized='incremental',
    unique_key='logical_request_id',
    incremental_strategy='delete+insert',
    on_schema_change='sync_all_columns'
) }}
-- depends_on: {{ ref('int_deduplicated_request_events') }}
with lines as (
    select * from {{ ref('int_billing_lines') }}
),
filtered as (
    select l.*
    from lines l
    {% if is_incremental() %}
    where l.logical_request_id in (
        select logical_request_id
        from {{ ref('int_deduplicated_request_events') }}
        where event_timestamp >= {{ event_window_start() }}
    )
    {% endif %}
)
select
    billing_line_key,
    logical_request_id,
    account_id,
    model_id,
    coalesce(plan_id, 'plan_unresolved')      as plan_id,
    usage_date,
    request_created_at,
    usage_component,
    component_ordinal,
    observed_tokens,
    billable_tokens,
    is_billable,
    customer_pricing_version_id,
    price_per_million_tokens,
    currency,
    pricing_resolution_status,
    estimated_revenue_amount,
    source_event_id,
    current_timestamp                         as loaded_at
from filtered
