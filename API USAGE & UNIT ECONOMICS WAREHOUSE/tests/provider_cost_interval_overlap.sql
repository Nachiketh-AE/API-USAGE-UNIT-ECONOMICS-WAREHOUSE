-- No overlapping effective intervals for one provider cost key (TAD 29).
select
    a.provider_cost_version_id as version_a,
    b.provider_cost_version_id as version_b,
    a.provider_id, a.model_id, a.usage_component
from {{ ref('stg_provider_costs') }} a
join {{ ref('stg_provider_costs') }} b
  on  a.provider_id = b.provider_id
  and a.model_id = b.model_id
  and a.usage_component = b.usage_component
  and a.currency = b.currency
  and a.provider_cost_version_id < b.provider_cost_version_id
  and a.valid_from < coalesce(b.valid_to, cast('9999-12-31' as timestamptz))
  and b.valid_from < coalesce(a.valid_to, cast('9999-12-31' as timestamptz))
