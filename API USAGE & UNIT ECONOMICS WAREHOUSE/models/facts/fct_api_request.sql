{{ config(
    materialized='incremental',
    unique_key='logical_request_id',
    incremental_strategy='delete+insert',
    on_schema_change='sync_all_columns'
) }}
-- depends_on: {{ ref('int_deduplicated_request_events') }}
-- Grain: one resolved logical request (logical_request_id).
-- Incremental contract (TAD 35.2 / 35.3): select the logical_request_ids whose event history touches
-- the seven-day event-time window, re-read ALL versions for those ids, then replace one row per id.
with resolved as (
    select * from {{ ref('int_resolved_requests') }}
),
plans as (
    select * from {{ ref('int_request_plan_assignments') }}
),
filtered as (
    select r.*
    from resolved r
    {% if is_incremental() %}
    where r.logical_request_id in (
        select logical_request_id
        from {{ ref('int_deduplicated_request_events') }}
        where event_timestamp >= {{ event_window_start() }}
    )
    {% endif %}
)
select
    {{ surrogate_key(['f.logical_request_id']) }}                as request_key,
    f.logical_request_id,
    f.source_event_id,
    f.entity_version,
    f.account_id,
    f.model_id,
    coalesce(p.plan_id, 'plan_unresolved')                       as plan_id,
    coalesce(p.plan_match_status, 'missing')                     as plan_match_status,
    f.request_date,
    f.request_created_at,
    f.request_resolved_at,
    f.request_status,
    case when f.request_status <> 'pending' then true else false end   as is_resolved,
    f.input_tokens,
    f.output_tokens,
    case when f.input_tokens is null then true else false end          as has_missing_input_usage,
    case when f.output_tokens is null then true else false end         as has_missing_output_usage,
    f.source_event_timestamp,
    f.source_ingested_at,
    current_timestamp                                            as loaded_at
from filtered f
left join plans p using (logical_request_id)
