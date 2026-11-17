{{ config(materialized='table') }}
-- Grain: one date x account x model x plan. Billing and revenue mart (PRD page 2).
-- Revenue is reduced from fct_billing_line only; no attempt rows are ever joined here.
with spine as (
    select distinct usage_date, account_id, model_id, plan_id
    from {{ ref('fct_usage_daily') }}
),
requests as (
    select
        request_date as usage_date, account_id, model_id, plan_id,
        count(*) filter (where request_status = 'pending') as pending_request_count,
        count(*) filter (where request_status = 'succeeded') as succeeded_request_count
    from {{ ref('fct_api_request') }}
    group by 1, 2, 3, 4
),
billing as (
    select
        usage_date, account_id, model_id, plan_id,
        sum(billable_tokens) filter (where usage_component = 'input' and is_billable)  as billable_input_tokens,
        sum(billable_tokens) filter (where usage_component = 'output' and is_billable) as billable_output_tokens,
        sum(coalesce(estimated_revenue_amount, 0))                                     as known_estimated_revenue_usd,
        count(*)                                                                       as actual_billing_line_count,
        count(*) filter (where pricing_resolution_status in ('priced', 'free_zero_rate')) as priced_line_count,
        count(*) filter (where pricing_resolution_status in ('missing_price', 'missing_plan', 'overlap')) as missing_price_line_count,
        count(*) filter (where pricing_resolution_status = 'missing_usage')            as missing_usage_line_count,
        sum(estimated_revenue_amount) filter (where is_billable)                       as paid_revenue_usd
    from {{ ref('fct_billing_line') }}
    group by 1, 2, 3, 4
),
joined as (
    select
        s.usage_date, s.account_id, s.model_id, s.plan_id,
        coalesce(b.billable_input_tokens, 0)     as billable_input_tokens,
        coalesce(b.billable_output_tokens, 0)    as billable_output_tokens,
        coalesce(b.known_estimated_revenue_usd, 0) as known_estimated_revenue_usd,
        coalesce(r.pending_request_count, 0)     as pending_request_count,
        coalesce(r.succeeded_request_count, 0) * 2 as expected_billing_line_count,
        coalesce(b.priced_line_count, 0)         as priced_line_count,
        coalesce(b.missing_price_line_count, 0)  as missing_price_line_count,
        coalesce(b.missing_usage_line_count, 0)  as missing_usage_line_count,
        coalesce(b.paid_revenue_usd, 0)          as known_paid_revenue_usd
    from spine s
    left join requests r using (usage_date, account_id, model_id, plan_id)
    left join billing  b using (usage_date, account_id, model_id, plan_id)
)
select
    usage_date,
    account_id,
    model_id,
    plan_id,
    billable_input_tokens,
    billable_output_tokens,
    known_estimated_revenue_usd,
    known_paid_revenue_usd,
    case
        when pending_request_count = 0
         and missing_price_line_count = 0
         and missing_usage_line_count = 0
        then known_estimated_revenue_usd
    end                                                       as estimated_revenue_usd,
    pending_request_count,
    expected_billing_line_count,
    priced_line_count,
    missing_price_line_count,
    missing_usage_line_count,
    case
        when pending_request_count = 0
         and missing_price_line_count = 0
         and missing_usage_line_count = 0
        then true else false
    end                                                       as revenue_is_complete,
    'USD'                                                     as currency,
    true                                                      as is_simulated
from joined
