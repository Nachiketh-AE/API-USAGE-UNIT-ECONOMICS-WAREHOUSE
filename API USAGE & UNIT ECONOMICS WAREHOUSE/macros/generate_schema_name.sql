{#
  Keep the TAD schema names exactly as documented (`raw`, `staging`, `intermediate`, `analytics`).
  Without this override dbt prefixes custom schemas with the target schema, producing
  `analytics_raw`, which would not match the documented architecture.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
