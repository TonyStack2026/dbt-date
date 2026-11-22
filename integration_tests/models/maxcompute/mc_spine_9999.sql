-- Spine straddling MaxCompute's documented default sequence() cap: by default sequence()
-- yields at most 10,000 elements (https://www.alibabacloud.com/help/en/maxcompute/sequence-1).
-- 9999 daily rows from 2000-01-01 with an end-exclusive bound of 2027-05-18, so the expected
-- membership is exactly 2000-01-01 .. 2027-05-17. Built through the real dbt path
-- (get_base_dates -> date_spine -> maxcompute__generate_series) on the repo's own maxcompute
-- target, which sets no odps.* session flag -- i.e. the documented default limit applies.
-- What is required of the output is asserted in tests/maxcompute/mc_assert_spine_range_limits.sql.
{{ config(materialized='table', tags=['maxcompute']) }}
{{ dbt_date.get_base_dates(start_date='2000-01-01', end_date='2027-05-18', datepart='day') }}
