-- Control input for mc_assert_negative_controls -- nothing else reads it.
-- The project-default-timezone leg with one expected case_id removed.
{{ config(materialized='table', tags=['maxcompute']) }}
select case_id, actual_shift_seconds
from {{ ref('mc_timezone_default_zone') }}
where case_id <> 'tvar_jan'
