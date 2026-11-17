{{ config(
    materialized='incremental',
    unique_key='attempt_id',
    incremental_strategy='delete+insert',
    on_schema_change='sync_all_columns'
) }}
-- depends_on: {{ ref('int_deduplicated_attempt_events') }}
-- Grain: one resolved execution attempt (attempt_id).
-- Account and plan are inherited from the parent logical request; pending attempts are retained here
-- and are never implied to be zero cost.
with attempts as (
    select * from {{ ref('int_resolved_attempts') }}
),
requests as (
    select logical_request_id, account_id from {{ ref('int_resolved_requests') }}
),
plans as (
    select logical_request_id, plan_id from {{ ref('int_request_plan_assignments') }}
),
filtered as (
    select a.*
    from attempts a
    {% if is_incremental() %}
    where a.attempt_id in (
        select attempt_id
        from {{ ref('int_deduplicated_attempt_events') }}
        where event_timestamp >= {{ event_window_start() }}
    )
    {% endif %}
)
select
    {{ surrogate_key(['f.attempt_id']) }}                        as attempt_key,
    f.attempt_id,
    f.logical_request_id,
    r.account_id,
    f.model_id,
    coalesce(p.plan_id, 'plan_unresolved')                       as plan_id,
    f.attempt_date,
    f.attempt_number,
    f.attempt_started_at,
    f.attempt_completed_at,
    f.attempt_status,
    f.input_tokens,
    f.output_tokens,
    f.resource_consumption_status,
    case when f.input_tokens is null then true else false end          as has_missing_input_usage,
    case when f.output_tokens is null then true else false end         as has_missing_output_usage,
    f.source_event_id,
    f.entity_version,
    f.source_event_timestamp,
    f.source_ingested_at,
    current_timestamp                                            as loaded_at
from filtered f
left join requests r using (logical_request_id)
left join plans p using (logical_request_id)
