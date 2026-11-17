{{ config(materialized='table') }}
-- Grain: one date x account x model x plan. Business-facing usage mart (PRD page 1).
with daily as (
    select * from {{ ref('fct_usage_daily') }}
)
select
    d.usage_date,
    d.account_id,
    a.account_name,
    a.account_segment,
    a.country_code,
    d.model_id,
    m.model_name,
    d.plan_id,
    p.plan_name,
    d.total_requests,
    d.succeeded_requests,
    d.failed_requests,
    d.timed_out_requests,
    d.cancelled_requests,
    d.pending_requests,
    d.resolved_requests,
    d.input_tokens_known,
    d.output_tokens_known,
    case
        when d.requests_missing_input_usage = 0 and d.requests_missing_output_usage = 0
        then coalesce(d.input_tokens_known, 0) + coalesce(d.output_tokens_known, 0)
    end                                                  as total_tokens,
    d.requests_missing_input_usage,
    d.requests_missing_output_usage,
    case
        when d.requests_missing_input_usage = 0 and d.requests_missing_output_usage = 0
        then true else false
    end                                                  as usage_is_complete,
    -- additive active-account counter: sums to COUNT(DISTINCT account_id) over any date range
    case when d.total_requests > 0 then 1 else 0 end      as active_account_count,
    case when d.total_requests > 0 then d.succeeded_requests * 1.0 / d.total_requests end as success_rate,
    case
        when (d.failed_requests + d.timed_out_requests + d.cancelled_requests) > 0
        then (d.failed_requests + d.timed_out_requests + d.cancelled_requests) * 1.0
             / (d.failed_requests + d.timed_out_requests + d.cancelled_requests + d.succeeded_requests)
    end                                                  as error_rate,
    d.billable_input_tokens,
    d.billable_output_tokens,
    'USD'                                                as currency,
    true                                                 as is_simulated
from daily d
left join {{ ref('dim_account') }} a on a.account_id = d.account_id
left join {{ ref('dim_model') }}   m on m.model_id = d.model_id
left join {{ ref('dim_plan') }}    p on p.plan_id = d.plan_id
