-- Control input for mc_assert_negative_controls -- nothing else reads it.
--
-- Same shape as mc_timezone_shifts, with the two corruptions the reviewer named applied to it:
-- one expected case_id removed, and one measured value replaced by NULL. The real assertion
-- before this commit (inner join + bare `<>`) reported neither.
{{ config(materialized='table', tags=['maxcompute']) }}
select case_id,
       case when case_id = 'tz_ambig_la_fall' then cast(null as bigint)
            else actual_shift_seconds end as actual_shift_seconds
from {{ ref('mc_timezone_shifts') }}
where case_id <> 'tz_xyear_sh_to_la'
