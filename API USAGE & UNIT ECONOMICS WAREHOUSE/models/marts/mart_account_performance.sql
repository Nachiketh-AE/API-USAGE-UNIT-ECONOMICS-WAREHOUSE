{{ config(materialized='table') }}
-- Grain: one month x account. Month spine includes zero-activity months so prior-month growth is comparable.
with account_spine as (
    select a.account_id from {{ ref('dim_account') }} a
),
month_spine as (
    select distinct month_start from {{ ref('dim_date') }}
),
spine as (
    select m.month_start, a.account_id
    from month_spine m cross join account_spine a
),
requests as (
    select
        cast(date_trunc('month', r.request_date) as date) as month_start,
        r.account_id,
        count(*)                                              as total_requests,
        count(*) filter (where r.request_status = 'succeeded') as succeeded_requests,
        count(*) filter (where r.request_status = 'failed')    as failed_requests,
        count(*) filter (where r.request_status = 'timed_out') as timed_out_requests,
        count(*) filter (where r.request_status = 'cancelled') as cancelled_requests,
        count(*) filter (where r.request_status = 'pending')   as pending_requests,
        sum(r.input_tokens)                                   as input_tokens_known,
        sum(r.output_tokens)                                  as output_tokens_known,
        count(*) filter (where r.input_tokens is null or r.output_tokens is null) as requests_with_missing_usage
    from {{ ref('fct_api_request') }} r
    group by 1, 2
),
attempts as (
    select
        cast(date_trunc('month', a.attempt_date) as date) as month_start,
        a.account_id,
        count(*) filter (where a.attempt_status = 'pending') as pending_attempts
    from {{ ref('fct_api_attempt') }} a
    group by 1, 2
),
billing as (
    select
        cast(date_trunc('month', b.usage_date) as date) as month_start,
        b.account_id,
        sum(b.billable_tokens) filter (where b.usage_component = 'input' and b.is_billable)  as billable_input_tokens,
        sum(b.billable_tokens) filter (where b.usage_component = 'output' and b.is_billable) as billable_output_tokens,
        sum(coalesce(b.estimated_revenue_amount, 0))                                          as known_estimated_revenue_usd,
        sum(case when b.pricing_resolution_status in ('priced', 'free_zero_rate') then 0 else 1 end) as incomplete_billing_line_count
    from {{ ref('fct_billing_line') }} b
    group by 1, 2
),
costs as (
    select
        cast(date_trunc('month', c.usage_date) as date) as month_start,
        c.account_id,
        sum(coalesce(c.estimated_provider_cost_amount, 0))                                            as known_estimated_provider_cost_usd,
        sum(case when c.cost_resolution_status in ('priced', 'not_consumed_zero') then 0 else 1 end)   as incomplete_provider_cost_line_count
    from {{ ref('fct_provider_cost_line') }} c
    group by 1, 2
),
joined as (
    select
        s.month_start,
        s.account_id,
        coalesce(r.total_requests, 0)             as total_requests,
        coalesce(r.succeeded_requests, 0)         as succeeded_requests,
        coalesce(r.failed_requests, 0)            as failed_requests,
        coalesce(r.timed_out_requests, 0)         as timed_out_requests,
        coalesce(r.cancelled_requests, 0)         as cancelled_requests,
        coalesce(r.pending_requests, 0)           as pending_requests,
        coalesce(a.pending_attempts, 0)           as pending_attempts,
        r.input_tokens_known,
        r.output_tokens_known,
        coalesce(r.requests_with_missing_usage, 0) as requests_with_missing_usage,
        b.billable_input_tokens,
        b.billable_output_tokens,
        coalesce(b.known_estimated_revenue_usd, 0)         as known_estimated_revenue_usd,
        coalesce(c.known_estimated_provider_cost_usd, 0)   as known_estimated_provider_cost_usd,
        coalesce(b.incomplete_billing_line_count, 0)       as incomplete_billing_line_count,
        coalesce(c.incomplete_provider_cost_line_count, 0) as incomplete_provider_cost_line_count
    from spine s
    left join requests r using (month_start, account_id)
    left join attempts a using (month_start, account_id)
    left join billing  b using (month_start, account_id)
    left join costs    c using (month_start, account_id)
),
measured as (
    select
        j.*,
        case when requests_with_missing_usage = 0
             then coalesce(input_tokens_known, 0) + coalesce(output_tokens_known, 0) end as total_tokens,
        case when requests_with_missing_usage = 0 then true else false end            as usage_is_complete,
        case when pending_requests = 0 and incomplete_billing_line_count = 0 then true else false end as revenue_is_complete,
        case when pending_requests = 0 and pending_attempts = 0
              and incomplete_provider_cost_line_count = 0 then true else false end    as cost_is_complete
    from joined j
),
with_month_flags as (
    select
        m.*,
        case
            when month_start < cast(date_trunc('month', current_date) as date)
             and usage_is_complete then true else false
        end as month_is_complete
    from measured m
),
with_prior as (
    select
        w.*,
        lag(total_tokens) over (partition by account_id order by month_start)          as prior_total_tokens,
        lag(month_is_complete) over (partition by account_id order by month_start)     as prior_month_is_complete
    from with_month_flags w
),
final as (
    select
        w.month_start,
        w.account_id,
        w.total_requests,
        w.succeeded_requests,
        w.failed_requests,
        w.timed_out_requests,
        w.cancelled_requests,
        w.pending_requests,
        w.pending_attempts,
        w.input_tokens_known,
        w.output_tokens_known,
        w.total_tokens,
        w.usage_is_complete,
        w.month_is_complete,
        case
            when w.month_is_complete and w.prior_month_is_complete
             and w.prior_total_tokens is not null and w.prior_total_tokens <> 0
            then (w.total_tokens - w.prior_total_tokens) * 100.0 / w.prior_total_tokens
        end                                                                     as usage_growth_pct,
        w.billable_input_tokens,
        w.billable_output_tokens,
        w.known_estimated_revenue_usd,
        case when w.revenue_is_complete then w.known_estimated_revenue_usd end    as estimated_revenue_usd,
        w.known_estimated_provider_cost_usd,
        case when w.cost_is_complete then w.known_estimated_provider_cost_usd end as estimated_provider_cost_usd,
        case when w.revenue_is_complete and w.cost_is_complete
             then w.known_estimated_revenue_usd - w.known_estimated_provider_cost_usd end as estimated_gross_profit_usd,
        case when w.revenue_is_complete and w.cost_is_complete and w.known_estimated_revenue_usd > 0
             then (w.known_estimated_revenue_usd - w.known_estimated_provider_cost_usd)
                  / w.known_estimated_revenue_usd * 100 end                     as estimated_gross_margin_pct,
        w.revenue_is_complete,
        w.cost_is_complete,
        w.incomplete_billing_line_count,
        w.incomplete_provider_cost_line_count,
        'USD'                                                                   as currency
    from with_prior w
)
select * from final
