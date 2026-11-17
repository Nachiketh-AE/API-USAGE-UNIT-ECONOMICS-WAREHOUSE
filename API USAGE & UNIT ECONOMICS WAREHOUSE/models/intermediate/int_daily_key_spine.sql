-- Grain: one usage_date x account x model x plan key observed anywhere in the warehouse.
-- A shared key spine lets each mart reduce its own fact *independently* before joining,
-- which is what prevents request-to-attempt join fanout (TAD 15.5 aggregation rule, TAD 47).
with keys as (
    select request_date as usage_date, account_id, model_id, plan_id from {{ ref('fct_api_request') }}
    union
    select usage_date, account_id, model_id, plan_id from {{ ref('fct_billing_line') }}
    union
    select usage_date, account_id, model_id, plan_id from {{ ref('fct_provider_cost_line') }}
)
select
    usage_date,
    account_id,
    model_id,
    coalesce(plan_id, 'plan_unresolved') as plan_id
from keys
