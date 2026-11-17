-- A request-level revenue figure must never be multiplied by attempt rows (TAD 47, ADR-010).
-- The atomic billing fact total must equal the fully aggregated mart total, to the cent.
with atomic as (
    select sum(coalesce(estimated_revenue_amount, 0)) as revenue
    from {{ ref('fct_billing_line') }}
),
mart as (
    select sum(known_estimated_revenue_usd) as revenue
    from {{ ref('mart_revenue_performance') }}
),
unit as (
    select sum(known_estimated_revenue_usd) as revenue
    from {{ ref('mart_unit_economics') }}
)
select 'mart_revenue_performance' as compared_to, atomic.revenue as atomic_revenue, mart.revenue as compared_revenue
from atomic, mart
where abs(atomic.revenue - mart.revenue) > 0.00000001
union all
select 'mart_unit_economics', atomic.revenue, unit.revenue
from atomic, unit
where abs(atomic.revenue - unit.revenue) > 0.00000001
