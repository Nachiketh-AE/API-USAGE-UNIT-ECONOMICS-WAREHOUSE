{{ config(materialized='table') }}
-- Grain: one date x account x model x plan.
-- Revenue and provider cost are each reduced independently to the daily key and only then joined,
-- so request-level revenue can never be multiplied by attempt rows (TAD 47, ADR-010).
with spine as (
    select * from {{ ref('int_daily_key_spine') }}
),
requests as (
    select
        request_date as usage_date, account_id, model_id, plan_id,
        count(*) filter (where request_status = 'pending') as pending_request_count
    from {{ ref('fct_api_request') }}
    group by 1, 2, 3, 4
),
attempts as (
    select
        attempt_date as usage_date, account_id, model_id, plan_id,
        count(*) filter (where attempt_status = 'pending') as pending_attempt_count
    from {{ ref('fct_api_attempt') }}
    group by 1, 2, 3, 4
),
billing as (
    select
        usage_date, account_id, model_id, plan_id,
        sum(coalesce(estimated_revenue_amount, 0))          as known_estimated_revenue_usd,
        sum(case when pricing_resolution_status in ('priced', 'free_zero_rate') then 1 else 0 end) as complete_billing_line_count,
        sum(case when pricing_resolution_status in ('priced', 'free_zero_rate') then 0 else 1 end) as incomplete_billing_line_count,
        count(*)                                            as billing_line_count
    from {{ ref('fct_billing_line') }}
    group by 1, 2, 3, 4
),
costs as (
    select
        usage_date, account_id, model_id, plan_id,
        sum(coalesce(estimated_provider_cost_amount, 0))    as known_estimated_provider_cost_usd,
        sum(case when cost_resolution_status in ('priced', 'not_consumed_zero') then 0 else 1 end) as incomplete_provider_cost_line_count,
        count(*)                                            as provider_cost_line_count
    from {{ ref('fct_provider_cost_line') }}
    group by 1, 2, 3, 4
),
joined as (
    select
        s.usage_date, s.account_id, s.model_id, s.plan_id,
        coalesce(b.known_estimated_revenue_usd, 0)          as known_estimated_revenue_usd,
        coalesce(c.known_estimated_provider_cost_usd, 0)    as known_estimated_provider_cost_usd,
        coalesce(r.pending_request_count, 0)                as pending_request_count,
        coalesce(att.pending_attempt_count, 0)               as pending_attempt_count,
        coalesce(b.incomplete_billing_line_count, 0)        as incomplete_billing_line_count,
        coalesce(c.incomplete_provider_cost_line_count, 0)  as incomplete_provider_cost_line_count,
        coalesce(b.billing_line_count, 0)                   as billing_line_count,
        coalesce(c.provider_cost_line_count, 0)             as provider_cost_line_count
    from spine s
    left join requests r using (usage_date, account_id, model_id, plan_id)
    left join attempts att using (usage_date, account_id, model_id, plan_id)
    left join billing  b using (usage_date, account_id, model_id, plan_id)
    left join costs    c using (usage_date, account_id, model_id, plan_id)
),
flags as (
    select
        j.*,
        case
            when pending_request_count = 0 and incomplete_billing_line_count = 0 then true else false
        end as revenue_is_complete,
        case
            when pending_request_count = 0 and pending_attempt_count = 0
             and incomplete_provider_cost_line_count = 0 then true else false
        end as cost_is_complete
    from joined j
)
select
    usage_date,
    account_id,
    model_id,
    plan_id,
    known_estimated_revenue_usd,
    case when revenue_is_complete then known_estimated_revenue_usd end     as estimated_revenue_usd,
    known_estimated_provider_cost_usd,
    case when cost_is_complete then known_estimated_provider_cost_usd end  as estimated_provider_cost_usd,
    case
        when revenue_is_complete and cost_is_complete
        then known_estimated_revenue_usd - known_estimated_provider_cost_usd
    end                                                                    as estimated_gross_profit_usd,
    case
        when revenue_is_complete and cost_is_complete and known_estimated_revenue_usd > 0
        then (known_estimated_revenue_usd - known_estimated_provider_cost_usd)
             / known_estimated_revenue_usd * 100
    end                                                                    as estimated_gross_margin_pct,
    revenue_is_complete,
    cost_is_complete,
    pending_request_count,
    pending_attempt_count,
    incomplete_billing_line_count,
    incomplete_provider_cost_line_count,
    billing_line_count,
    provider_cost_line_count,
    'USD'                                                                  as currency,
    true                                                                   as is_simulated
from flags
