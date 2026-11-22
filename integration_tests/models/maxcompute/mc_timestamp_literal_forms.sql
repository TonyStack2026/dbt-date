-- Accepted inputs of maxcompute_timestamp_literal(), rendered at compile time.
-- Every expected value here is the text the macro must emit, and the reason for each shape is
-- measured in tests/maxcompute/mc_assert_timezone_default_zone.sql's sibling assertion
-- (mc_assert_timestamp_literal_forms.sql): the same string is also read back by the server, so
-- a normalisation that MaxCompute interprets differently fails the assertion rather than
-- shipping a NULL column.
{{ config(materialized='table', tags=['maxcompute']) }}
select 'space_seconds' as case_id,
       '{{ dbt_date.maxcompute_timestamp_literal("2026-01-01 10:20:30") }}' as rendered,
       '2026-01-01 10:20:30' as expected_rendered,
       timestamp'2026-01-01 10:20:30' as expected_value
union all
select 'date_only',
       '{{ dbt_date.maxcompute_timestamp_literal("2026-01-01") }}',
       '2026-01-01 00:00:00',
       timestamp'2026-01-01 00:00:00'
union all
-- The shape the review pointed at: an ISO `T` separator. A literal accepts it, but the same
-- text through cast() is silently NULL, so the helper must not pass it through.
select 'iso_T',
       '{{ dbt_date.maxcompute_timestamp_literal("2026-01-01T10:20:30") }}',
       '2026-01-01 10:20:30',
       timestamp'2026-01-01 10:20:30'
union all
select 'fraction_millis',
       '{{ dbt_date.maxcompute_timestamp_literal("2026-01-01 10:20:30.123") }}',
       '2026-01-01 10:20:30.123',
       timestamp'2026-01-01 10:20:30.123000'
union all
-- Longer than 19 characters used to be cut at 19, which silently dropped the fraction.
select 'fraction_micros_with_T',
       '{{ dbt_date.maxcompute_timestamp_literal("2026-01-01T10:20:30.123456") }}',
       '2026-01-01 10:20:30.123456',
       timestamp'2026-01-01 10:20:30.123456'
union all
select 'unpadded',
       '{{ dbt_date.maxcompute_timestamp_literal("2026-1-1 1:2:3") }}',
       '2026-01-01 01:02:03',
       timestamp'2026-01-01 01:02:03'
union all
select 'padded_surrounding_spaces',
       '{{ dbt_date.maxcompute_timestamp_literal("  2026-01-01T10:20:30  ") }}',
       '2026-01-01 10:20:30',
       timestamp'2026-01-01 10:20:30'
union all
select 'date_object',
       '{{ dbt_date.maxcompute_timestamp_literal(modules.datetime.date(2026, 1, 1)) }}',
       '2026-01-01 00:00:00',
       timestamp'2026-01-01 00:00:00'
union all
select 'datetime_object',
       '{{ dbt_date.maxcompute_timestamp_literal(modules.datetime.datetime(2026, 1, 1, 10, 20, 30)) }}',
       '2026-01-01 10:20:30',
       timestamp'2026-01-01 10:20:30'
union all
-- The review's second point: the datetime-object branch used to render whole seconds only, so
-- a naive datetime with microseconds lost them at compile time while the string branch kept
-- them. Both shapes are pinned here -- expected_rendered is what the macro must emit, and
-- expected_value is what the server must read it back as, so a silent truncation (or a server
-- that keeps fewer digits than we render) shows up as a failing row.
select 'datetime_object_micros',
       '{{ dbt_date.maxcompute_timestamp_literal(modules.datetime.datetime(2026, 1, 1, 10, 20, 30, 123456)) }}',
       '2026-01-01 10:20:30.123456',
       timestamp'2026-01-01 10:20:30.123456'
union all
-- Small non-zero microsecond value: catches an implementation that renders the fraction
-- without zero-padding (5 -> '.5' would read back as half a second, not five microseconds).
select 'datetime_object_micros_padded',
       '{{ dbt_date.maxcompute_timestamp_literal(modules.datetime.datetime(2026, 1, 1, 10, 20, 30, 5)) }}',
       '2026-01-01 10:20:30.000005',
       timestamp'2026-01-01 10:20:30.000005'
union all
-- And the zero case must stay clean: no trailing dot, no '.000000' noise.
select 'datetime_object_no_micros',
       '{{ dbt_date.maxcompute_timestamp_literal(modules.datetime.datetime(2026, 1, 1, 10, 20, 30, 0)) }}',
       '2026-01-01 10:20:30',
       timestamp'2026-01-01 10:20:30'
