-- Grain: one unique source_event_id.
-- Raw uniqueness is the primary control (raw PK); this is the defensive guard from TAD 15.3.
with source as (
    select * from {{ ref('stg_api_request_events') }}
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
    source_event_id, logical_request_id, entity_version, event_action, supersedes_event_id,
    account_id, model_id, request_created_at, request_resolved_at, event_timestamp,
    request_status, input_tokens, output_tokens, source_system, correction_reason,
    payload_hash, batch_id, ingested_at
from deduplicated
