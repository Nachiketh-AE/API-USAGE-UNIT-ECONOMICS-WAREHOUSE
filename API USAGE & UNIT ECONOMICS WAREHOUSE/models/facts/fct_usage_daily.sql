{{ config(materialized='table') }}
-- Grain: one account x model x plan x UTC date.
-- Request measures and billable tokens are each reduced to the grain *before* being joined;
-- no request-to-attempt raw join is used (TAD 15.5 aggregation rule).
with spine as (
    select
        r.request_date  as usage_date,
        r.account_id,
        r.model_id,
        r.plan_id
    from {{ ref('fct_api_request') }} r
    group by 1, 2, 3, 4
    union
    select
        b.usage_date,
        b.account_id,
        b.model_id,
        b.plan_id
    from {{ ref('fct_billing_line') }} b
    group by 1, 2, 3, 4
),
request_rollup as (
    select
        request_date                                        as usage_date,
        account_id,
        model_id,
        plan_id,
        count(*)                                            as total_requests,
        count(*) filter (where request_status = 'succeeded') as succeeded_requests,
        count(*) filter (where request_status = 'failed')    as failed_requests,
        count(*) filter (where request_status = 'timed_out') as timed_out_requests,
        count(*) filter (where request_status = 'cancelled') as cancelled_requests,
        count(*) filter (where request_status = 'pending')   as pending_requests,
        sum(input_tokens)                                    as input_tokens_known,
        sum(output_tokens)                                   as output_tokens_known,
        count(*) filter (where input_tokens is null)         as requests_missing_input_usage,
        count(*) filter (where output_tokens is null)        as requests_missing_output_usage,
        max(source_ingested_at)                              as source_max_ingested_at
    from {{ ref('fct_api_request') }}
    group by 1, 2, 3, 4
),
billing_rollup as (
    select
        usage_date,
        account_id,
        model_id,
        plan_id,
        sum(billable_tokens) filter (where usage_component = 'input')  as billable_input_tokens,
        sum(billable_tokens) filter (where usage_component = 'output') as billable_output_tokens
    from {{ ref('fct_billing_line') }}
    where is_billable
    group by 1, 2, 3, 4
)
select
    s.usage_date,
    s.account_id,
    s.model_id,
    s.plan_id,
    coalesce(r.total_requests, 0)               as total_requests,
    coalesce(r.succeeded_requests, 0)           as succeeded_requests,
    coalesce(r.failed_requests, 0)              as failed_requests,
    coalesce(r.timed_out_requests, 0)           as timed_out_requests,
    coalesce(r.cancelled_requests, 0)           as cancelled_requests,
    coalesce(r.pending_requests, 0)             as pending_requests,
    coalesce(r.succeeded_requests, 0)
      + coalesce(r.failed_requests, 0)
      + coalesce(r.timed_out_requests, 0)
      + coalesce(r.cancelled_requests, 0)       as resolved_requests,
    r.input_tokens_known,
    r.output_tokens_known,
    coalesce(r.requests_missing_input_usage, 0) as requests_missing_input_usage,
    coalesce(r.requests_missing_output_usage, 0) as requests_missing_output_usage,
    b.billable_input_tokens,
    b.billable_output_tokens,
    coalesce(r.source_max_ingested_at, current_timestamp) as source_max_ingested_at,
    current_timestamp                           as loaded_at
from spine s
left join request_rollup r using (usage_date, account_id, model_id, plan_id)
left join billing_rollup b using (usage_date, account_id, model_id, plan_id)
