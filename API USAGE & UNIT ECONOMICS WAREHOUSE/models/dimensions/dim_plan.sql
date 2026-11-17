-- Grain: one plan. The `plan_unresolved` sentinel member prevents a NULL plan from silently
-- dropping a fact row out of a plan-keyed mart (finding F-06).
with plans as (
    select * from {{ ref('stg_plans') }}
)
select
    plan_key,
    plan_id,
    plan_name,
    plan_description,
    is_free_plan,
    is_active,
    false as is_sentinel
from (
    select {{ surrogate_key(['plan_id']) }} as plan_key, plan_id, plan_name, plan_description,
           is_free_plan, is_active
    from plans
) p
union all
select
    {{ surrogate_key(["'plan_unresolved'"]) }} as plan_key,
    'plan_unresolved' as plan_id,
    'Unresolved plan' as plan_name,
    'Sentinel member: the plan could not be resolved for the request; fact rows are kept visible.' as plan_description,
    false as is_free_plan,
    false as is_active,
    true as is_sentinel
