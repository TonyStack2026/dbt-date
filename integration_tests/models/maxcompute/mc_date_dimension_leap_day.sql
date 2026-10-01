-- Calendar dimension for a fixed window, checked column by column against independently
-- derived values: ISO-8601 week numbering (week 1 contains 4 January), Sunday-based
-- week_start/week_end, MaxCompute dayofweek() numbering with Sunday=1, day_of_year,
-- month/quarter/year boundaries including leap days, and prior-year columns using
-- MaxCompute dateadd clamping. Note week_of_year equals iso_week_of_year here --
-- MaxCompute only has ISO week numbering (see README).
{{ config(materialized='table', tags=['maxcompute']) }}
{{ dbt_date.get_date_dimension('2024-02-23', '2024-03-06') }}
