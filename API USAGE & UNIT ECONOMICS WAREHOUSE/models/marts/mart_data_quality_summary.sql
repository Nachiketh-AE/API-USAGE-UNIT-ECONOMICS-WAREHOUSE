{{ config(materialized='table') }}
-- Grain: one row for the warehouse as a whole. Single "is the data fit to certify" status strip
-- for dashboard headers (PRD section 20: no dashboard may imply zero defects by exclusion).
with deliveries as (
    select
        count(*)                                                      as total_deliveries,
        count(*) filter (where delivery_outcome = 'accepted')          as accepted_deliveries,
        count(*) filter (where delivery_outcome = 'duplicate')         as duplicate_deliveries,
        count(*) filter (where delivery_outcome = 'quarantined')       as quarantined_deliveries,
        count(*) filter (where delivery_outcome = 'backfill_required') as backfill_required_deliveries,
        max(received_at)                                              as last_delivery_at
    from {{ ref('stg_event_delivery_log') }}
),
quarantine as (
    select count(*) as quarantine_rows from {{ ref('stg_quarantined_events') }}
),
requests as (
    select
        count(*)                                                        as resolved_requests,
        count(*) filter (where request_status = 'pending')              as pending_requests,
        count(*) filter (where input_tokens is null)                    as requests_missing_input_usage,
        count(*) filter (where output_tokens is null)                   as requests_missing_output_usage,
        count(*) filter (where plan_match_status <> 'matched')          as requests_unresolved_plan
    from {{ ref('fct_api_request') }}
),
attempts as (
    select
        count(*)                                                        as resolved_attempts,
        count(*) filter (where attempt_status = 'pending')              as pending_attempts
    from {{ ref('fct_api_attempt') }}
),
billing as (
    select
        count(*)                                                            as billing_lines,
        count(*) filter (where pricing_resolution_status not in ('priced', 'free_zero_rate')) as incomplete_billing_lines
    from {{ ref('fct_billing_line') }}
),
costs as (
    select
        count(*)                                                                       as provider_cost_lines,
        count(*) filter (where cost_resolution_status not in ('priced', 'not_consumed_zero')) as incomplete_provider_cost_lines
    from {{ ref('fct_provider_cost_line') }}
)
select
    d.total_deliveries,
    d.accepted_deliveries,
    d.duplicate_deliveries,
    d.quarantined_deliveries,
    d.backfill_required_deliveries,
    q.quarantine_rows,
    d.last_delivery_at,
    r.resolved_requests,
    r.pending_requests,
    r.requests_missing_input_usage,
    r.requests_missing_output_usage,
    r.requests_unresolved_plan,
    a.resolved_attempts,
    a.pending_attempts,
    b.billing_lines,
    b.incomplete_billing_lines,
    c.provider_cost_lines,
    c.incomplete_provider_cost_lines,
    case
        when d.quarantined_deliveries = 0 and d.backfill_required_deliveries = 0
         and r.requests_unresolved_plan = 0 and b.incomplete_billing_lines = 0
         and c.incomplete_provider_cost_lines = 0 and a.pending_attempts = 0
         and r.pending_requests = 0
        then true else false
    end as warehouse_is_certified,
    true as is_simulated
from deliveries d
cross join quarantine q
cross join requests r
cross join attempts a
cross join billing b
cross join costs c
