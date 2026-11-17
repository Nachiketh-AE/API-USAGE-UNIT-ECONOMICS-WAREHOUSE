{% test nexora_assert_expression(model, expression, column_name=none) %}
select * from {{ model }} where not ({{ expression }})
{% endtest %}
