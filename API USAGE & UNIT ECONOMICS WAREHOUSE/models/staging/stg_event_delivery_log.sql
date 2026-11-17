select
    cast(delivery_id as varchar)               as delivery_id,
    cast(batch_id as varchar)                  as batch_id,
    trim(source_event_id)                      as source_event_id,
    lower(trim(entity_type))                   as entity_type,
    trim(payload_hash)                         as payload_hash,
    cast(received_at as timestamptz)           as received_at,
    lower(trim(delivery_outcome))              as delivery_outcome,
    trim(reason_code)                          as reason_code,
    trim(reason_detail)                        as reason_detail
from {{ source('raw', 'event_delivery_log') }}
