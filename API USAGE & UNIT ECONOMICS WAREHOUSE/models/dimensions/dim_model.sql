-- Grain: one API model (static MVP dimension).
select
    {{ surrogate_key(['model_id']) }} as model_key,
    model_id,
    model_name,
    model_family,
    provider_id,
    provider_name,
    model_status,
    input_unit,
    output_unit,
    model_created_at,
    retired_at,
    source_updated_at
from {{ ref('stg_models') }}
