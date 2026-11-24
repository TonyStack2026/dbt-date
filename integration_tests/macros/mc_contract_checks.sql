{#-
  Shared comparison logic for the MaxCompute contract tests.

  Why a macro instead of inline SQL per test: the review on head 8b8d598 showed that `join`
  plus a bare `<>` makes an assertion vacuous -- a missing expected key never appears, and a
  NULL actual compares UNKNOWN so its row is dropped. Both shapes are handled here (expected-key
  driven LEFT JOIN + explicit IS NULL), and the *same* code path is pointed at deliberately
  broken inputs in tests/maxcompute/mc_assert_negative_controls.sql, which is worth more than a
  control that only re-describes the logic.

  Every macro returns the same five columns so callers can union freely:
      failure_kind, subject, detail, actual, expected
  A returned row means one violated expectation; an empty result means the contract holds.
-#}

{%- macro mc_timezone_shift_cases() -%}
{{ return([
    ('tz_sh_to_la_jan', 57600), ('tz_sh_to_la_jul', 54000), ('tz_la_to_utc_jul', -25200),
    ('tz_utc_to_sh_jul', -28800), ('tz_la_to_la_jan', 0), ('tz_gap_la_spring', -28800),
    ('tz_ambig_la_fall', -25200), ('tz_xyear_sh_to_la', 57600)
]) }}
{%- endmacro -%}


{%- macro mc_timezone_default_zone_cases() -%}
{{ return([('tvar_jul', 25200), ('tvar_jan', 28800)]) }}
{%- endmacro -%}


{% macro mc_shift_violations(subject, model_relation, cases) -%}
{%- set literals = [] -%}
{%- for case_id, expected in cases -%}
{%- do literals.append("select '%s' as case_id, %d as expected_shift" | format(case_id, expected)) -%}
{%- endfor -%}
with mc_exp as (
    {{ literals | join("\n    union all\n") }}
),
mc_act as (
    select case_id, actual_shift_seconds from {{ model_relation }}
)
select 'missing_expected_key' as failure_kind, '{{ subject }}' as subject, e.case_id as detail,
       cast(null as string) as actual, cast(e.expected_shift as string) as expected
from mc_exp e
left join mc_act a on a.case_id = e.case_id
where a.case_id is null

union all

select 'null_or_wrong_value', '{{ subject }}', a.case_id,
       cast(a.actual_shift_seconds as string), cast(e.expected_shift as string)
from mc_exp e
join mc_act a on a.case_id = e.case_id
where a.actual_shift_seconds is null or a.actual_shift_seconds <> e.expected_shift

union all

select 'unexpected_key', '{{ subject }}', a.case_id,
       cast(a.actual_shift_seconds as string), cast(null as string)
from mc_act a
left join mc_exp e on e.case_id = a.case_id
where e.case_id is null
{%- endmacro %}


{%- macro mc_day_count_violations(subject, model_relation, expected_days) -%}
{#- A distinct-day count compared against an expectation. The column returned as the violation
    marker is always 1: reporting the measured count there (which is what this check used to do)
    makes an EMPTY model produce mismatching_rows = 0, and the outer
    `where mismatching_rows > 0` then filters the row out -- the emptiest corruption passing.
    The measured value is still visible: it is carried as text in `actual`. -#}
with mc_d as (
    select count(*) as n from (select distinct date_day from {{ model_relation }}) x
)
select 'day_count' as failure_kind, '{{ subject }}' as subject, 'distinct date_day' as detail,
       cast(n as string) as actual, '{{ expected_days }}' as expected
from mc_d
where n <> {{ expected_days }}
{%- endmacro -%}


{% macro mc_date_key_violations(subject, model_relation, expected_relation) -%}
{#- Row count / min / max cannot see an interior day dropped while another is duplicated.
    This compares date-key multiplicities: 0/1 means dropped, 2/1 means duplicated.
    Deliberately no leading WITH: this macro gets UNION ALL'd with others, and
    "union all <with ...>" is a parse error on MaxCompute (measured 11-22: the CTE form made
    mc_assert_dimension_coverage fail with ParseError, while the inline-view form below runs). -#}
select 'date_key_multiplicity' as failure_kind, '{{ subject }}' as subject,
       cast(coalesce(a.date_day, e.date_day) as string) as detail,
       cast(coalesce(a.actual_n, 0) as string) as actual,
       cast(coalesce(e.expected_n, 0) as string) as expected
from (
    select date_day, count(*) as actual_n from {{ model_relation }} group by date_day
) a
full outer join (
    select date_day, count(*) as expected_n from {{ expected_relation }} group by date_day
) e on a.date_day = e.date_day
where coalesce(a.actual_n, 0) <> coalesce(e.expected_n, 0)
{%- endmacro -%}


{% macro mc_date_shape_violations(subject, model_relation, expected_relation) -%}
{#- The shape check the reviewer called insufficient. Kept -- it is still the cheapest guard
    against a shifted window -- but separated so the negative control can show which check is
    load-bearing for which corruption. -#}
select 'row_count' as failure_kind, '{{ subject }}' as subject, 'count(*)' as detail,
       cast(m.n as string) as actual, cast(e.n as string) as expected
from (select count(*) as n from {{ model_relation }}) m,
     (select count(*) as n from {{ expected_relation }}) e
where m.n <> e.n

union all

select 'span', '{{ subject }}', 'min .. max',
       cast(concat(cast(m.mn as string), ' .. ', cast(m.mx as string)) as string),
       cast(concat(cast(e.mn as string), ' .. ', cast(e.mx as string)) as string)
from (select min(date_day) as mn, max(date_day) as mx from {{ model_relation }}) m,
     (select min(date_day) as mn, max(date_day) as mx from {{ expected_relation }}) e
where m.mn <> e.mn or m.mx <> e.mx
{%- endmacro %}

{% macro mc_spine_membership_violations(subject, model_relation, expected_rows, expected_first, expected_last) -%}
{#- Exact membership of a daily spine. Reviewer point on 6fc2d46: counting distinct timestamps on a
    TIMESTAMP column is not counting days -- replacing 2000-01-02 00:00:00 with 2000-01-01 12:00:00
    leaves row count, distinct timestamp count, min .. max and window width all identical while a
    calendar day is gone. So day identity is asserted twice:
      * distinct_calendar_day_count -- count(distinct cast(date_day as date)) must equal the rows
      * non_midnight_rows           -- every value must read as "<date> 00:00:00"; compared as text
                                      because cast(<ts> as string) keeps a fraction
                                      ('... 00:00:00.5'), so sub-second shifts are caught too
                                      (both renderings measured 11-24)
    plus the shape checks: rows, distinct timestamps, both endpoints, and the server-measured
    window width (the timestamp overload of datediff, which is the form the 11-22 run proved this
    engine accepts).

    Written with one inline aggregate view per branch, never a leading WITH: this macro is
    UNION ALL-ed four times by mc_assert_spine_range_limits and `UNION ALL <WITH>` is a parse
    error on MaxCompute -- that is exactly how the first version of this macro failed the suite
    on 11-24 (mc_assert_dimension_coverage hit the same rule on 11-22). -#}
{%- set agg = "(select count(*) as n_rows, count(distinct date_day) as n_ts, count(distinct cast(date_day as date)) as n_days, sum(case when cast(date_day as string) <> concat(cast(cast(date_day as date) as string), ' 00:00:00') then 1 else 0 end) as n_nonmidnight, min(date_day) as lo, max(date_day) as hi, datediff(max(date_day), min(date_day), 'dd') + 1 as n_width from " ~ model_relation ~ ") mc_a" -%}
select 'row_count' as failure_kind, '{{ subject }}' as subject, 'count(*)' as detail,
       cast(n_rows as string) as actual, '{{ expected_rows }}' as expected
from {{ agg }}
where n_rows <> {{ expected_rows }}

union all

select 'distinct_timestamp_count', '{{ subject }}', 'count(distinct date_day)',
       cast(n_ts as string), '{{ expected_rows }}'
from {{ agg }}
where n_ts <> {{ expected_rows }}

union all

select 'distinct_calendar_day_count', '{{ subject }}', 'count(distinct cast(date_day as date))',
       cast(n_days as string), '{{ expected_rows }}'
from {{ agg }}
where n_days <> {{ expected_rows }}

union all

select 'non_midnight_rows', '{{ subject }}', 'rows whose text is not <date> 00:00:00',
       cast(n_nonmidnight as string), '0'
from {{ agg }}
where n_nonmidnight <> 0

union all

select 'first_day', '{{ subject }}', 'min(date_day)',
       cast(lo as string), '{{ expected_first }}'
from {{ agg }}
where cast(lo as string) <> '{{ expected_first }}'

union all

select 'last_day', '{{ subject }}', 'max(date_day)',
       cast(hi as string), '{{ expected_last }}'
from {{ agg }}
where cast(hi as string) <> '{{ expected_last }}'

union all

select 'window_width_days', '{{ subject }}', 'datediff(max, min, dd) + 1',
       cast(n_width as string), '{{ expected_rows }}'
from {{ agg }}
where n_width <> {{ expected_rows }}
{%- endmacro -%}
