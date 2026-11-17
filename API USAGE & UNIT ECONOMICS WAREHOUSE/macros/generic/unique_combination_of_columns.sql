{% test unique_combination_of_columns(model, combination_of_columns, quote_columns=false) %}
with validation as (
    select {{ combination_of_columns | join(', ') }}, count(*) as row_count
    from {{ model }}
    group by {{ combination_of_columns | join(', ') }}
    having count(*) > 1
)
select * from validation
{% endtest %}
