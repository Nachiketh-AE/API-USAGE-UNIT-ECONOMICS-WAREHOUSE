-- Provider cost rules (PRD 16, TAD 31):
--  * a pending attempt is never costed in this fact
--  * not_consumed is an explicit zero, never a NULL and never a missing rate
--  * priced lines carry a rate and an amount; unknown consumption never becomes zero
select c.provider_cost_line_key, c.attempt_id, c.cost_resolution_status
from {{ ref('fct_provider_cost_line') }} c
left join {{ ref('fct_api_attempt') }} a using (attempt_id)
where a.attempt_status = 'pending'
   or (c.cost_resolution_status = 'not_consumed_zero' and coalesce(c.estimated_provider_cost_amount, -1) <> 0)
   or (c.cost_resolution_status = 'priced' and (c.cost_per_million_tokens is null or c.estimated_provider_cost_amount is null))
   or (c.cost_resolution_status = 'unknown_consumption' and c.estimated_provider_cost_amount is not null)
   or c.estimated_provider_cost_amount < 0
