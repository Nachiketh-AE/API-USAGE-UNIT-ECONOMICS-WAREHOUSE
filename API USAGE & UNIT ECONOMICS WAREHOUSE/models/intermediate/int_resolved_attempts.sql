-- Grain: one execution attempt.
with versions as (
    select * from {{ ref('int_deduplicated_attempt_events') }}
),
ranked as (
    select
        *,
        row_number() over (
            partition by attempt_id
            order by entity_version desc, event_timestamp desc, ingested_at desc
        ) as _rn,
        max(entity_version) over (partition by attempt_id) as _max_version
    from versions
)
select
    attempt_id,
    logical_request_id,
    source_event_id,
    entity_version,
    event_action,
    supersedes_event_id,
    attempt_number,
    model_id,
    attempt_started_at,
    attempt_completed_at,
    event_timestamp        as source_event_timestamp,
    attempt_status,
    input_tokens,
    output_tokens,
    resource_consumption_status,
    correction_reason,
    payload_hash,
    batch_id,
    ingested_at            as source_ingested_at,
    cast(attempt_started_at as date) as attempt_date,
    _max_version           as resolved_max_version,
    case when entity_version = _max_version then 'latest' else 'superseded' end as version_status
from ranked
where _rn = 1
