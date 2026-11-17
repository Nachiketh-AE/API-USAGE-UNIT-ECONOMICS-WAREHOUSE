-- No overlapping effective intervals for one customer price key (TAD 27, PRD FR-011).
select
    a.customer_pricing_version_id as version_a,
    b.customer_pricing_version_id as version_b,
    a.model_id, a.plan_id, a.usage_component
from {{ ref('stg_customer_pricing') }} a
join {{ ref('stg_customer_pricing') }} b
  on  a.model_id = b.model_id
  and a.plan_id = b.plan_id
  and a.usage_component = b.usage_component
  and a.currency = b.currency
  and a.customer_pricing_version_id < b.customer_pricing_version_id
  and a.valid_from < coalesce(b.valid_to, cast('9999-12-31' as timestamptz))
  and b.valid_from < coalesce(a.valid_to, cast('9999-12-31' as timestamptz))
