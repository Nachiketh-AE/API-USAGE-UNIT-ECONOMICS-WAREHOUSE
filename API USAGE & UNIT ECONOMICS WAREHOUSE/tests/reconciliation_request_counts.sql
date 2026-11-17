-- fct_usage_daily request counts must reconcile to fct_api_request (declared grain check).
with atomic as (
    select
        request_date as usage_date, account_id, model_id, plan_id,
        count(*) as total_requests,
        count(*) filter (where request_status = 'succeeded') as succeeded_requests,
        count(*) filter (where request_status = 'pending')   as pending_requests
    from {{ ref('fct_api_request') }}
    group by 1, 2, 3, 4
)
select d.usage_date, d.account_id, d.model_id, d.plan_id
from {{ ref('fct_usage_daily') }} d
left join atomic a using (usage_date, account_id, model_id, plan_id)
where d.total_requests  <> coalesce(a.total_requests, 0)
   or d.succeeded_requests <> coalesce(a.succeeded_requests, 0)
   or d.pending_requests <> coalesce(a.pending_requests, 0)
