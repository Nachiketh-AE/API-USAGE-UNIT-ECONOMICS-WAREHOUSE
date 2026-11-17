-- Grain: one terminal execution attempt x usage component.
-- Provider cost resolved at attempt_started_at, independently of customer pricing (TAD 29).
with attempts as (
    select * from {{ ref('int_resolved_attempts') }}
),
requests as (
    select r.logical_request_id, r.account_id, r.model_id as request_model_id,
           p.plan_id, p.plan_match_status
    from {{ ref('int_resolved_requests') }} r
    left join {{ ref('int_request_plan_assignments') }} p using (logical_request_id)
),
terminal as (
    select * from attempts where attempt_status <> 'pending'
),
joined as (
    select
        a.attempt_id,
        a.logical_request_id,
        a.model_id,
        r.account_id,
        r.plan_id,
        r.plan_match_status,
        a.attempt_number,
        a.attempt_started_at,
        a.attempt_completed_at,
        a.attempt_status,
        a.input_tokens,
        a.output_tokens,
        a.resource_consumption_status,
        a.source_event_id,
        cast(a.attempt_started_at as date) as usage_date
    from terminal a
    left join requests r using (logical_request_id)
),
components as (
    select 1 as component_ordinal, 'input' as usage_component, input_tokens as measured_tokens, j.*
    from joined j
    union all
    select 2 as component_ordinal, 'output' as usage_component, output_tokens as measured_tokens, j.*
    from joined j
),
schedules as (
    select * from {{ ref('stg_provider_costs') }}
),
models as (
    select model_id, provider_id from {{ ref('stg_models') }}
),
matched as (
    select
        c.attempt_id, c.logical_request_id, c.model_id, c.account_id, c.plan_id, c.plan_match_status,
        c.attempt_number, c.attempt_started_at, c.attempt_completed_at, c.attempt_status,
        c.resource_consumption_status, c.source_event_id, c.usage_date,
        c.component_ordinal, c.usage_component, c.measured_tokens,
        s.provider_cost_version_id, s.cost_per_million_tokens, s.currency,
        count(s.provider_cost_version_id) over (partition by c.attempt_id, c.usage_component) as cost_match_count
    from components c
    join models m on m.model_id = c.model_id
    left join schedules s
        on  s.provider_id = m.provider_id
        and s.model_id = c.model_id
        and s.usage_component = c.usage_component
        and s.currency = 'USD'
        and s.valid_from <= c.attempt_started_at
        and (s.valid_to is null or c.attempt_started_at < s.valid_to)
)
select
    attempt_id, logical_request_id, model_id, account_id, plan_id, plan_match_status,
    attempt_number, attempt_started_at, attempt_completed_at, attempt_status,
    resource_consumption_status, source_event_id, usage_date,
    component_ordinal, usage_component, measured_tokens,
    case when cost_match_count = 1 then provider_cost_version_id else null end as provider_cost_version_id,
    case when cost_match_count = 1 then cost_per_million_tokens else null end as cost_per_million_tokens,
    cast(coalesce(currency, 'USD') as varchar) as currency,
    cost_match_count,
    case
        when resource_consumption_status = 'not_consumed' then 'not_consumed_zero'
        when resource_consumption_status = 'unknown' then 'unknown_consumption'
        when measured_tokens is null then 'missing_usage'
        when cost_match_count = 0 then 'missing_rate'
        when cost_match_count > 1 then 'overlap'
        else 'priced'
    end as cost_resolution_status
from matched
