-- Fixed-range date spine built from literal start/end dates.
-- Expectation: a closed interval -- one row per period, both endpoints included
-- (2026-01-01..2026-03-01 daily = 60 rows), and month/year arithmetic clamps to the
-- last valid day the way MaxCompute dateadd does (2024-01-31 +1 month = 2024-02-29).
{{ config(materialized='table', tags=['maxcompute']) }}
{{ dbt_date.get_base_dates(start_date='2024-01-31', end_date='2024-04-30', datepart='month') }}
