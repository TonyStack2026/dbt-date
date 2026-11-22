-- Control input for mc_assert_negative_controls -- nothing else reads it.
-- The emptiest corruption the fiscal day-count check can see: zero distinct days.
{{ config(materialized='table', tags=['maxcompute']) }}
select * from {{ ref('mc_fiscal_periods') }}
where 1 = 0
