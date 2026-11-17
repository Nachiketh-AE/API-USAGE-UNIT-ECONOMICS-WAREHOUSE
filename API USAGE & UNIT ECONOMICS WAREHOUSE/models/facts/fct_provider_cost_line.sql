{{ config(
    materialized='incremental',
    unique_key='attempt_id',
    incremental_strategy='delete+insert',
    on_schema_change='sync_all_columns'
) }}
-- depends_on: {{ ref('int_deduplicated_attempt_events') }}
-- Grain: one terminal execution attempt x usage component.
-- Pending attempts never enter this fact; they remain visible in fct_api_attempt (TAD 15.5).
with lines as (
    select * from {{ ref('int_provider_cost_lines') }}
),
filtered as (
    select l.*
    from lines l
    {% if is_incremental() %}
    where l.attempt_id in (
        select attempt_id
        from {{ ref('int_deduplicated_attempt_events') }}
        where event_timestamp >= {{ event_window_start() }}
    )
    {% endif %}
)
select
    provider_cost_line_key,
    attempt_id,
    logical_request_id,
    account_id,
    model_id,
    coalesce(plan_id, 'plan_unresolved')      as plan_id,
    usage_date,
    attempt_started_at,
    usage_component,
    component_ordinal,
    measured_tokens,
    resource_consumption_status,
    provider_cost_version_id,
    cost_per_million_tokens,
    currency,
    cost_resolution_status,
    estimated_provider_cost_amount,
    source_event_id,
    current_timestamp                         as loaded_at
from filtered
