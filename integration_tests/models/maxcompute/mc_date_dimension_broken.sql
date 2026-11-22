-- Control input for mc_assert_negative_controls -- nothing else reads it.
--
-- The corruption that row count / min / max cannot see: one interior day dropped (2026-01-05)
-- and another interior day duplicated (2026-01-06). Row count, min and max all stay identical
-- to the expectation, so mc_date_shape_violations must report 0 here while
-- mc_date_key_violations must report exactly those two date keys.
{{ config(materialized='table', tags=['maxcompute']) }}
select * from {{ ref('mc_date_dimension_cross_year') }}
where date_day <> date'2026-01-05'

union all

select * from {{ ref('mc_date_dimension_cross_year') }}
where date_day = date'2026-01-06'
