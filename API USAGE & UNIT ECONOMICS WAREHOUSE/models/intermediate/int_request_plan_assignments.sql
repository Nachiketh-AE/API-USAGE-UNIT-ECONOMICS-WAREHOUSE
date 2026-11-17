-- Grain: one logical request.
-- Plan resolved at request_created_at against half-open intervals (TAD 26/27, PRD A-005).
with requests as (
    select * from {{ ref('int_resolved_requests') }}
),
intervals as (
    select * from {{ ref('stg_account_plan_history') }}
),
matches as (
    select
        r.logical_request_id,
        r.account_id,
        r.request_created_at,
        i.account_plan_history_id,
        i.plan_id,
        count(*) over (partition by r.logical_request_id) as match_count
    from requests r
    left join intervals i
        on  i.account_id = r.account_id
        and i.valid_from <= r.request_created_at
        and (i.valid_to is null or r.request_created_at < i.valid_to)
)
select
    logical_request_id,
    account_id,
    request_created_at,
    case when match_count = 1 then plan_id else null end as plan_id,
    case when match_count = 1 then account_plan_history_id else null end as account_plan_history_id,
    match_count,
    case
        when match_count = 1 then 'matched'
        when match_count = 0 then 'missing'
        else 'overlap'
    end as plan_match_status
from matches
