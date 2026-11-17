-- Grain: one terminal execution attempt x usage component.
-- Provider cost is independent of customer price and includes resource-consuming failed attempts (TAD 31).
with matched as (
    select * from {{ ref('int_provider_cost_match') }}
)
select
    {{ surrogate_key(['attempt_id', 'usage_component']) }}    as provider_cost_line_key,
    attempt_id,
    logical_request_id,
    account_id,
    model_id,
    plan_id,
    usage_date,
    attempt_started_at,
    usage_component,
    component_ordinal,
    measured_tokens,
    resource_consumption_status,
    provider_cost_version_id,
    cost_per_million_tokens,
    currency,
    cost_resolution_status,
    case
        when resource_consumption_status = 'not_consumed' then cast(0 as decimal(20,8))
        when resource_consumption_status = 'unknown' then null
        when measured_tokens is null or cost_per_million_tokens is null then null
        else {{ token_amount('measured_tokens', 'cost_per_million_tokens') }}
    end                                                       as estimated_provider_cost_amount,
    source_event_id
from matched
