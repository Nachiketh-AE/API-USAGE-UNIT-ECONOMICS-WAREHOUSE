-- Account plan assignment intervals must not overlap for the same account (TAD 26, PRD FR-010).
select
    a.account_plan_history_id as interval_a,
    b.account_plan_history_id as interval_b,
    a.account_id
from {{ ref('stg_account_plan_history') }} a
join {{ ref('stg_account_plan_history') }} b
  on  a.account_id = b.account_id
  and a.account_plan_history_id < b.account_plan_history_id
  and a.valid_from < coalesce(b.valid_to, cast('9999-12-31' as timestamptz))
  and b.valid_from < coalesce(a.valid_to, cast('9999-12-31' as timestamptz))
