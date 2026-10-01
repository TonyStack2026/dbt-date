{% macro get_intervals_between(start_date, end_date, datepart) -%}
    {{ return(adapter.dispatch('get_intervals_between', 'dbt_date')(start_date, end_date, datepart)) }}
{%- endmacro %}

{% macro default__get_intervals_between(start_date, end_date, datepart) -%}
    {%- call statement('get_intervals_between', fetch_result=True) %}

        select {{ dbt.datediff(start_date, end_date, datepart) }}

    {%- endcall -%}

    {%- set value_list = load_result('get_intervals_between') -%}

    {%- if value_list and value_list['data'] -%}
        {%- set values = value_list['data'] | map(attribute=0) | list %}
        {{ return(values[0]) }}
    {%- else -%}
        {{ return(1) }}
    {%- endif -%}

{%- endmacro %}




{% macro date_spine(datepart, start_date, end_date) %}
    {{ return(adapter.dispatch('date_spine', 'dbt_date')(datepart, start_date, end_date)) }}
{%- endmacro %}

{% macro default__date_spine(datepart, start_date, end_date) %}


{# call as follows:

date_spine(
    "day",
    "to_date('01/01/2016', 'mm/dd/yyyy')",
    "dbt.dateadd(week, 1, current_date)"
) #}


with rawdata as (

    {{
        dbt_date.generate_series(
            dbt_date.get_intervals_between(start_date, end_date, datepart)
        )
    }}

),

all_periods as (

    select (
        {{
            dbt.dateadd(
                datepart,
                "(row_number() over (order by 1) - 1)",
                start_date
            )
        }}
    ) as date_{{datepart}}
    from rawdata

),

filtered as (

    select *
    from all_periods
    where date_{{datepart}} <= {{ end_date }}

)

select * from filtered

{% endmacro %}

{% macro maxcompute__date_spine(datepart, start_date, end_date) %}
{#
  Two MaxCompute-specific departures from the default implementation:
    1. the row source: default__date_spine calls generate_series(), whose cross-join
       body MaxCompute rejects (ODPS-0130252); see maxcompute__generate_series.
    2. the shape: the default emits a WITH block, and get_base_dates already wraps this
       macro inside `with date_spine as ( ... )`, so a nested WITH/lateral view would sit
       inside a CTE. This version stays a single flat SELECT so it can be embedded anywhere.
  sequence(0, intervals) yields intervals + 1 offsets, so the period at end_date itself is
  kept by the `datediff(...) <= 0` filter (closed interval, same as the other adapters).
#}
select * from (

    select (
        {{
            dbt.dateadd(
                datepart,
                'mc_seq.val',
                start_date
            )
        }}
    ) as date_{{datepart}}
    from (select 1 as mc_seed) mc_row
    lateral view explode(sequence(0, {{ dbt_date.get_intervals_between(start_date, end_date, datepart) }})) mc_seq as val

) mc_periods
where datediff(date_{{datepart}}, {{ end_date }}) <= 0
{% endmacro %}
