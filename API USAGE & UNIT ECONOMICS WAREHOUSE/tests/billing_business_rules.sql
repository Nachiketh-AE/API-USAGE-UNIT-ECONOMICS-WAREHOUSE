-- Billing eligibility rules (PRD 15, TAD 30):
--  * only successful requests are billed
--  * a Free-plan line is never paid billable usage
--  * billable tokens are non-negative and never exceed observed tokens
--  * a priced line always carries a rate and an amount
select billing_line_key, logical_request_id, pricing_resolution_status, billable_tokens, observed_tokens
from {{ ref('fct_billing_line') }} b
left join {{ ref('fct_api_request') }} r using (logical_request_id)
where r.request_status <> 'succeeded'
   or (b.plan_id = 'free' and b.is_billable)
   or b.billable_tokens < 0
   or (b.billable_tokens is not null and b.observed_tokens is not null and b.billable_tokens > b.observed_tokens)
   or (b.pricing_resolution_status = 'priced' and (b.price_per_million_tokens is null or b.estimated_revenue_amount is null))
   or (b.pricing_resolution_status = 'free_zero_rate' and coalesce(b.estimated_revenue_amount, 1) <> 0)
