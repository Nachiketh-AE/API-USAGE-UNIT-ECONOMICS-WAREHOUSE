select
    cast(quarantine_id as varchar)             as quarantine_id,
    cast(delivery_id as varchar)               as delivery_id,
    cast(batch_id as varchar)                  as batch_id,
    lower(cast(entity_type as varchar))        as entity_type,
    cast(source_event_id as varchar)           as source_event_id,
    cast(raw_payload as varchar)               as raw_payload,
    cast(error_codes as varchar)               as error_codes,
    cast(quarantined_at as timestamptz)        as quarantined_at,
    cast(resolved_at as timestamptz)           as resolved_at,
    cast(resolution_note as varchar)           as resolution_note
from {{ source('raw', 'quarantined_events') }}
