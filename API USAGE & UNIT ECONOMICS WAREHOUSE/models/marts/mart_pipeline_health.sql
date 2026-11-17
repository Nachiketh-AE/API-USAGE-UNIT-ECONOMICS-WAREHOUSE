{{ config(materialized='table') }}
-- Grain: one ingestion batch. Publishes the operational data-quality state that PRD section 20/21
-- require dashboards to disclose, without exposing raw tables to the BI role (finding F-01).
with batches as (
    select * from {{ ref('stg_ingestion_batches') }}
),
deliveries as (
    select
        batch_id,
        count(*)                                                       as delivery_count,
        count(*) filter (where delivery_outcome = 'accepted')           as accepted_count,
        count(*) filter (where delivery_outcome = 'duplicate')          as duplicate_count,
        count(*) filter (where delivery_outcome = 'quarantined')        as quarantined_count,
        count(*) filter (where delivery_outcome = 'backfill_required')  as backfill_required_count,
        max(received_at)                                                as last_delivery_at
    from {{ ref('stg_event_delivery_log') }}
    group by 1
),
quarantine as (
    select batch_id, count(*) as quarantine_rows,
           count(*) filter (where resolved_at is null) as open_quarantine_rows
    from {{ ref('stg_quarantined_events') }}
    group by 1
)
select
    b.batch_id,
    b.source_name,
    b.source_file_name,
    b.generator_seed,
    b.batch_status,
    b.started_at,
    b.completed_at,
    b.code_version,
    b.error_message,
    coalesce(d.delivery_count, 0)            as delivery_count,
    coalesce(d.accepted_count, 0)            as accepted_delivery_count,
    coalesce(d.duplicate_count, 0)           as duplicate_delivery_count,
    coalesce(d.quarantined_count, 0)         as quarantined_delivery_count,
    coalesce(d.backfill_required_count, 0)   as backfill_required_count,
    coalesce(q.quarantine_rows, 0)           as quarantine_row_count,
    coalesce(q.open_quarantine_rows, 0)      as open_quarantine_row_count,
    d.last_delivery_at,
    case when coalesce(d.quarantined_count, 0) > 0 or coalesce(d.backfill_required_count, 0) > 0
         then true else false end            as requires_operator_action,
    true                                     as is_simulated
from batches b
left join deliveries d using (batch_id)
left join quarantine q using (batch_id)
