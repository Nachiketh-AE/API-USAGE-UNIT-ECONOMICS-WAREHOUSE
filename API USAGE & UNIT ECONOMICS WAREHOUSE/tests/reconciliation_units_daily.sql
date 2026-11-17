-- fct_usage_daily billable tokens must reconcile exactly to the atomic billing fact,
-- proving the aggregate was built by independent reduction rather than a fanout join.
with atomic as (
    select
        usage_date, account_id, model_id, plan_id,
        sum(billable_tokens) filter (where usage_component = 'input')  as input_tokens,
        sum(billable_tokens) filter (where usage_component = 'output') as output_tokens
    from {{ ref('fct_billing_line') }}
    where is_billable
    group by 1, 2, 3, 4
)
select d.usage_date, d.account_id, d.model_id, d.plan_id
from {{ ref('fct_usage_daily') }} d
left join atomic a using (usage_date, account_id, model_id, plan_id)
where coalesce(d.billable_input_tokens, 0)  <> coalesce(a.input_tokens, 0)
   or coalesce(d.billable_output_tokens, 0) <> coalesce(a.output_tokens, 0)
