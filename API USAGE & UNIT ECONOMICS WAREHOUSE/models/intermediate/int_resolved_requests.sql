-- Grain: one logical request.
-- Correction resolution: highest valid entity_version wins (TAD 25.2 / 35.3). Raw history is untouched.
with versions as (
    select * from {{ ref('int_deduplicated_request_events') }}
),
ranked as (
    select
        *,
        row_number() over (
            partition by logical_request_id
            order by entity_version desc, event_timestamp desc, ingested_at desc
        ) as _rn,
        max(entity_version) over (partition by logical_request_id) as _max_version
    from versions
)
select
    logical_request_id,
    source_event_id,
    entity_version,
    event_action,
    supersedes_event_id,
    account_id,
    model_id,
    request_created_at,
    request_resolved_at,
    event_timestamp        as source_event_timestamp,
    request_status,
    input_tokens,
    output_tokens,
    correction_reason,
    payload_hash,
    batch_id,
    ingested_at            as source_ingested_at,
    cast(request_created_at as date) as request_date,
    _max_version           as resolved_max_version,
    case when entity_version = _max_version then 'latest' else 'superseded' end as version_status
from ranked
where _rn = 1
