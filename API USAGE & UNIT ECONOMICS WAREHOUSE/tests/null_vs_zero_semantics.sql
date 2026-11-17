-- NULL means unknown and 0 means measured zero; the two must never be conflated (PRD 18, TAD 15.7).
-- A missing usage keeps its NULL and is counted; a genuine zero survives aggregation as 0.
select request_key, logical_request_id
from {{ ref('fct_api_request') }}
where (input_tokens is null)  <> has_missing_input_usage
   or (output_tokens is null) <> has_missing_output_usage
   or input_tokens < 0
   or output_tokens < 0
