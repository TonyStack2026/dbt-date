-- Spans at and around MaxCompute's documented default sequence() cap (10,000 elements per
-- call: https://www.alibabacloud.com/help/en/maxcompute/sequence-1), built through the real dbt
-- path on the repo's own maxcompute target, which sets no odps.* session flag.
--
-- What is required: exact membership, not "some rows came back". Per span the assertion pins
-- row count, distinct day count, the first day and the last day, and the width of the
-- [min .. max] window. Those four together leave no room for a gap, a duplicate or an
-- off-by-one: `rows` distinct days inside a window that is exactly `rows` days wide, anchored
-- at both ends, is the window.
--
-- Expected values below are written from calendar arithmetic in this project's own test layer
-- (independent of the macro under test), and the 10,001-row span is the case that a
-- single-call sequence() cannot produce under the documented default.
with mc_expected as (
    select 'spine_9999' as span_name, 9999 as expected_rows,
           timestamp'2000-01-01 00:00:00' as expected_first, timestamp'2027-05-17 00:00:00' as expected_last
    union all
    select 'spine_10000' as span_name, 10000 as expected_rows,
           timestamp'2000-01-01 00:00:00' as expected_first, timestamp'2027-05-18 00:00:00' as expected_last
    union all
    select 'spine_10001' as span_name, 10001 as expected_rows,
           timestamp'2000-01-01 00:00:00' as expected_first, timestamp'2027-05-19 00:00:00' as expected_last
),
mc_actual as (
    select 'spine_9999' as span_name, count(*) as actual_rows, count(distinct date_day) as actual_distinct,
           min(date_day) as actual_first, max(date_day) as actual_last,
           datediff(max(date_day), min(date_day), 'dd') + 1 as actual_width
    from {{ ref('mc_spine_9999') }}
    union all
    select 'spine_10000' as span_name, count(*) as actual_rows, count(distinct date_day) as actual_distinct,
           min(date_day) as actual_first, max(date_day) as actual_last,
           datediff(max(date_day), min(date_day), 'dd') + 1 as actual_width
    from {{ ref('mc_spine_10000') }}
    union all
    select 'spine_10001' as span_name, count(*) as actual_rows, count(distinct date_day) as actual_distinct,
           min(date_day) as actual_first, max(date_day) as actual_last,
           datediff(max(date_day), min(date_day), 'dd') + 1 as actual_width
    from {{ ref('mc_spine_10001') }}
)
select e.span_name, 'row_count' as failure_kind,
       cast(a.actual_rows as string) as actual, cast(e.expected_rows as string) as expected
from mc_expected e
left join mc_actual a on a.span_name = e.span_name
where a.span_name is null or a.actual_rows <> e.expected_rows

union all

select e.span_name, 'distinct_day_count',
       cast(a.actual_distinct as string), cast(e.expected_rows as string)
from mc_expected e
left join mc_actual a on a.span_name = e.span_name
where a.actual_distinct is null or a.actual_distinct <> e.expected_rows

union all

select e.span_name, 'first_day',
       cast(a.actual_first as string), cast(e.expected_first as string)
from mc_expected e
left join mc_actual a on a.span_name = e.span_name
where a.actual_first is null or a.actual_first <> e.expected_first

union all

select e.span_name, 'last_day',
       cast(a.actual_last as string), cast(e.expected_last as string)
from mc_expected e
left join mc_actual a on a.span_name = e.span_name
where a.actual_last is null or a.actual_last <> e.expected_last

union all

-- the window width, measured on the server rather than assumed from the row count
select e.span_name, 'window_width_days',
       cast(a.actual_width as string), cast(e.expected_rows as string)
from mc_expected e
left join mc_actual a on a.span_name = e.span_name
where a.actual_width is null or a.actual_width <> e.expected_rows
