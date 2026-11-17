-- Grain: one UTC calendar date, spanning the observed request window.
with bounds as (
    select
        min(request_date) as min_date,
        max(request_date) as max_date
    from {{ ref('int_resolved_requests') }}
),
spine as (
    select cast(unnest(generate_series(min_date, max_date, interval 1 day)) as date) as date_day
    from bounds
)
select
    {{ surrogate_key(['date_day']) }}          as date_key,
    date_day,
    extract(year from date_day)                as year_number,
    extract(month from date_day)               as month_number,
    cast(date_trunc('month', date_day) as date) as month_start,
    extract(quarter from date_day)             as quarter_number,
    extract(day from date_day)                 as day_of_month,
    extract(isodow from date_day)              as iso_day_of_week,
    case when extract(isodow from date_day) in (6, 7) then true else false end as is_weekend,
    date_trunc('week', date_day)::date         as week_start
from spine
