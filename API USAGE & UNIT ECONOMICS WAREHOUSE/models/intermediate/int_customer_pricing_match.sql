-- Grain: one logical request x usage component.
-- Customer price resolved at request_created_at; a gap yields missing_price, never a rate substitution.
with requests as (
    select r.*, p.plan_id, p.plan_match_status, pl.is_free_plan
    from {{ ref('int_resolved_requests') }} r
    left join {{ ref('int_request_plan_assignments') }} p using (logical_request_id)
    left join {{ ref('stg_plans') }} pl on pl.plan_id = p.plan_id
),
components as (
    select logical_request_id, 1 as component_ordinal, 'input' as usage_component, input_tokens as observed_tokens from requests
    union all
    select logical_request_id, 2 as component_ordinal, 'output' as usage_component, output_tokens as observed_tokens from requests
),
labelled as (
    select
        c.logical_request_id,
        c.component_ordinal,
        c.usage_component,
        c.observed_tokens,
        r.account_id,
        r.model_id,
        r.plan_id,
        r.plan_match_status,
        coalesce(r.is_free_plan, false) as is_free_plan,
        r.request_status,
        r.request_created_at,
        r.request_date,
        r.source_event_id
    from components c
    join requests r using (logical_request_id)
),
pricing as (
    select * from {{ ref('stg_customer_pricing') }}
),
matched as (
    select
        l.*,
        p.customer_pricing_version_id,
        p.price_per_million_tokens,
        p.currency,
        p.valid_from,
        p.valid_to,
        count(p.customer_pricing_version_id) over (partition by l.logical_request_id, l.usage_component) as price_match_count
    from labelled l
    left join pricing p
        on  p.model_id = l.model_id
        and p.plan_id = l.plan_id
        and p.usage_component = l.usage_component
        and p.currency = 'USD'
        and p.valid_from <= l.request_created_at
        and (p.valid_to is null or l.request_created_at < p.valid_to)
)
select
    logical_request_id,
    component_ordinal,
    usage_component,
    observed_tokens,
    account_id,
    model_id,
    plan_id,
    plan_match_status,
    is_free_plan,
    request_status,
    request_created_at,
    request_date,
    source_event_id,
    case when price_match_count = 1 then customer_pricing_version_id else null end as customer_pricing_version_id,
    case when price_match_count = 1 then price_per_million_tokens else null end as price_per_million_tokens,
    cast(case when price_match_count > 1 then 'USD' else coalesce(currency, 'USD') end as varchar) as currency,
    price_match_count,
    case
        when is_free_plan and request_status = 'succeeded' then 'free_zero_rate'
        when request_status <> 'succeeded' then 'not_eligible'
        when plan_match_status <> 'matched' then 'missing_plan'
        when observed_tokens is null then 'missing_usage'
        when price_match_count = 0 then 'missing_price'
        when price_match_count > 1 then 'overlap'
        else 'priced'
    end as customer_pricing_status
from matched
