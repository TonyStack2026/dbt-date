{% macro get_powers_of_two(upper_bound) %}
    {{ return(adapter.dispatch('get_powers_of_two', 'dbt_date')(upper_bound)) }}
{% endmacro %}

{% macro default__get_powers_of_two(upper_bound) %}

    {% if upper_bound <= 0 %}
    {{ exceptions.raise_compiler_error("upper bound must be positive") }}
    {% endif %}

    {% for _ in range(1, 100) %}
       {% if upper_bound <= 2 ** loop.index %}{{ return(loop.index) }}{% endif %}
    {% endfor %}

{% endmacro %}


{% macro generate_series(upper_bound) %}
    {{ return(adapter.dispatch('generate_series', 'dbt_date')(upper_bound)) }}
{% endmacro %}

{% macro default__generate_series(upper_bound) %}

    {% set n = dbt_date.get_powers_of_two(upper_bound) %}

    with p as (
        select 0 as generated_number union all select 1
    ), unioned as (

    select

    {% for i in range(n) %}
    p{{i}}.generated_number * power(2, {{i}})
    {% if not loop.last %} + {% endif %}
    {% endfor %}
    + 1
    as generated_number

    from

    {% for i in range(n) %}
    p as p{{i}}
    {% if not loop.last %} cross join {% endif %}
    {% endfor %}

    )

    select *
    from unioned
    where generated_number <= {{upper_bound}}
    order by generated_number

{% endmacro %}

{% macro maxcompute__generate_series(upper_bound) %}
    {#
      Two separate MaxCompute facts shape this row source, and they are measured, not assumed.

      1. Cartesian products. Submitted with the engine's own defaults, the default body's
         cross join of a 2-row set to itself fails: ODPS-0130252 "cartesian product is not
         allowed without mapjoin" (probes I2/T1, 10-02). That is not what blocks it through
         dbt today, though - dbt-maxcompute sends odps.sql.allow.cartesian=true in its global
         hints, and re-running the default body through the adapter on 11-22 built without
         error. The native form is used anyway: it materialises exactly the rows asked for
         instead of 2^n from n cross-joined sets, and it does not rely on a flag this package
         does not own.

      2. The sequence() cap. Documented default is 10,000 elements per call, controlled by
         odps.sql.max.sequence.length (https://www.alibabacloud.com/help/en/maxcompute/sequence-1).
         The cap is enforced on this engine: with odps.sql.max.sequence.length=100,
         sequence(1, 1000) fails with ODPS-0121095 while sequence(1, 50) succeeds (11-22
         probes S6/S7). What does NOT reproduce here is the documented default biting: on this
         project sequence(1, 10001) and even sequence(1, 100001) return their full length
         today (probes S3/S5). So a long spine is not broken *now* - it is only safe because
         of a default this package neither sets nor observes.

      Hence: emit the offsets in chunks of at most 10,000 elements joined with UNION ALL. The
      emitted SQL stays inside the documented default for every span, so it neither needs the
      flag raised nor breaks if a project lowers it. Chunk i covers offsets i*CHUNK+1 ..
      min((i+1)*CHUNK, upper_bound); the pieces are disjoint and contiguous, so the result is
      exactly 1..upper_bound - the same row count default__generate_series yields for the same
      bound (asserted for 9,999 / 10,000 / 10,001-day spans by mc_assert_spine_range_limits,
      and chunk size itself was verified not to change the row set).
    #}
    {% if upper_bound <= 0 %}
    {{ exceptions.raise_compiler_error("upper bound must be positive") }}
    {% endif %}

    {%- set mc_chunk = 10000 -%}
    {%- set mc_chunks = ((upper_bound | int + mc_chunk - 1) // mc_chunk) | int -%}
    {%- for i in range(mc_chunks) -%}
    {%- set mc_lo = i * mc_chunk + 1 -%}
    {%- set mc_len = [mc_chunk, upper_bound | int - mc_lo + 1] | min -%}
    {%- if not loop.first %}
    union all
    {% endif -%}
    select mc_seq{{ i }}.val + {{ mc_lo - 1 }} as generated_number
    from (select 1 as mc_seed{{ i }}) mc_row{{ i }}
    lateral view explode(sequence(1, {{ mc_len }})) mc_seq{{ i }} as val
    {%- endfor -%}
{% endmacro %}
