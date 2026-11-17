-- An attempt must use the same model as its parent logical request in the MVP (TAD 13.3).
select a.attempt_id, a.model_id as attempt_model_id, r.model_id as request_model_id
from {{ ref('fct_api_attempt') }} a
join {{ ref('fct_api_request') }} r using (logical_request_id)
where a.model_id <> r.model_id
