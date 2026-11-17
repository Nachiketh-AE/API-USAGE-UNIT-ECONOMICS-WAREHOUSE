select
    cast(batch_id as varchar)                  as batch_id,
    trim(source_name)                          as source_name,
    trim(source_file_name)                     as source_file_name,
    cast(generator_seed as bigint)             as generator_seed,
    cast(started_at as timestamptz)            as started_at,
    cast(completed_at as timestamptz)          as completed_at,
    lower(trim(batch_status))                  as batch_status,
    cast(input_record_count as bigint)         as input_record_count,
    cast(accepted_delivery_count as bigint)    as accepted_delivery_count,
    cast(duplicate_delivery_count as bigint)   as duplicate_delivery_count,
    cast(quarantined_delivery_count as bigint) as quarantined_delivery_count,
    cast(backfill_required_count as bigint)    as backfill_required_count,
    trim(error_message)                        as error_message,
    trim(code_version)                         as code_version,
    cast(created_at as timestamptz)            as created_at
from {{ source('raw', 'ingestion_batches') }}
