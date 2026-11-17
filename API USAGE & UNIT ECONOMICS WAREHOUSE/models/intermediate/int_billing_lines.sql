-- Grain: one successful logical request x usage component (TAD 15.3 -> fct_billing_line input).
-- Centralised billing arithmetic (TAD 30). Revenue exists only for eligible successful requests.
with priced as (
    select * from {{ ref('int_customer_pricing_match') }}
)
select
    {{ surrogate_key(['logical_request_id', 'usage_component']) }} as billing_line_key,
    logical_request_id,
    account_id,
    model_id,
    plan_id,
    request_date                                              as usage_date,
    request_created_at,
    usage_component,
    component_ordinal,
    observed_tokens,
    case
        when is_free_plan then cast(0 as bigint)
        when observed_tokens is null then null
        else observed_tokens
    end                                                       as billable_tokens,
    case when is_free_plan then false else true end           as is_billable,
    customer_pricing_version_id,
    price_per_million_tokens,
    currency,
    customer_pricing_status                                   as pricing_resolution_status,
    case
        when is_free_plan then cast(0 as decimal(20,8))
        when observed_tokens is null or price_per_million_tokens is null then null
        else {{ token_amount('observed_tokens', 'price_per_million_tokens') }}
    end                                                       as estimated_revenue_amount,
    source_event_id
from priced
-- only successful requests are billing-eligible; ineligible components are counted, not billed
where request_status = 'succeeded'
