-- Grain: one unique source_event_id.
with source as (
    select * from {{ ref('stg_api_attempt_events') }}
),
deduplicated as (
    select *
    from (
        select
            source.*,
            row_number() over (
                partition by source_event_id
                order by ingested_at desc, entity_version desc
            ) as _rn
        from source
    ) ranked
    where _rn = 1
)
select
    source_event_id, attempt_id, logical_request_id, entity_version, event_action,
    supersedes_event_id, attempt_number, model_id, attempt_started_at, attempt_completed_at,
    event_timestamp, attempt_status, input_tokens, output_tokens, resource_consumption_status,
    source_system, correction_reason, payload_hash, batch_id, ingested_at
from deduplicated
