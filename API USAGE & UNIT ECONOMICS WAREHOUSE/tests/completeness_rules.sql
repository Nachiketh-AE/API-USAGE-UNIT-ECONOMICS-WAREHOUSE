-- Completeness semantics (PRD 18, A-013):
--  * a certified total must be NULL iff its completeness flag is false
--  * a known subtotal is always populated so partial information stays visible
--  * a margin is never present when gross profit is NULL
select usage_date, account_id, model_id, plan_id
from {{ ref('mart_unit_economics') }}
where (revenue_is_complete and estimated_revenue_usd is null and billing_line_count > 0)
   or (not revenue_is_complete and estimated_revenue_usd is not null)
   or (not cost_is_complete and estimated_provider_cost_usd is not null)
   or (cost_is_complete and estimated_provider_cost_usd is null and provider_cost_line_count > 0)
   or (estimated_gross_margin_pct is not null and estimated_gross_profit_usd is null)
   or known_estimated_revenue_usd is null
   or known_estimated_provider_cost_usd is null
