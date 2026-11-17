-- Events whose *event timestamp* is inside the seven-day window must be present in the facts,
-- even when their business timestamp is much older (TAD 35.3 affected-entity resolution).
with recent as (
    select logical_request_id
    from {{ ref('int_deduplicated_request_events') }}
    where event_timestamp >= (current_timestamp - interval '7 days')
),
fact as (
    select logical_request_id from {{ ref('fct_api_request') }}
)
select r.logical_request_id
from recent r
left join fact f using (logical_request_id)
where f.logical_request_id is null
