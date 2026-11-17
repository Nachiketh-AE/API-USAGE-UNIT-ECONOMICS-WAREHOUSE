{#- The automatic incremental window defined by TAD section 35.2: seven days of event time. -#}
{% macro event_window_start() -%}
    (current_timestamp - interval '7 days')
{%- endmacro %}

{% macro window_days() -%}7{%- endmacro %}

{#- Deterministic surrogate key: md5 over a canonical '|'-joined concatenation (TAD section 33). -#}
{% macro surrogate_key(columns) -%}
    md5(concat_ws('|', {% for c in columns %}coalesce(cast({{ c }} as varchar), '~'){% if not loop.last %}, {% endif %}{% endfor %}))
{%- endmacro %}

{% macro utc_date(expr) -%}
    cast({{ expr }} as date)
{%- endmacro %}

{#- Monetary amount: tokens / 1,000,000 * rate, kept in NUMERIC(20,8) (TAD section 15.7). -#}
{% macro token_amount(tokens, rate) -%}
    (cast({{ tokens }} as decimal(20,8)) / cast(1000000 as decimal(20,8))) * cast({{ rate }} as decimal(20,8))
{%- endmacro %}

{#- Delete+insert safety net for affected-key refresh on incremental financial facts (TAD section 35.5). -#}
{% macro noop() -%}select 1{%- endmacro %}
