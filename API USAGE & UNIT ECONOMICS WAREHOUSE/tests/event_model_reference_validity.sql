-- Every request/attempt event must reference a model that exists in stg_models.
-- Replaces the generic relationship test, which DuckDB resolves against the raw
-- catalog when staging views are recreated in the same full-refresh run.
with model_refs as (
    select 'api_request_events' as event_family, source_event_id, model_id
    from {{ ref('stg_api_request_events') }}
    union all
    select 'api_attempt_events' as event_family, source_event_id, model_id
    from {{ ref('stg_api_attempt_events') }}
),
known_models as (
    select model_id from {{ ref('stg_models') }}
)
select r.*
from model_refs r
left join known_models k on r.model_id = k.model_id
where r.model_id is not null
  and k.model_id is null
