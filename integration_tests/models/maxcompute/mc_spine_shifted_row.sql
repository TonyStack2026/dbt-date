-- Control input for mc_assert_negative_controls -- nothing else reads it.
--
-- The reviewer's counter-example, made permanent: take the 10,001-row spine and move the second
-- row from 2000-01-02 00:00:00 to 2000-01-01 12:00:00. Row count, distinct-timestamp count,
-- min, max and the datediff window width all stay exactly as before, yet a calendar day is gone.
-- A test that counts distinct timestamps cannot see this; the day-identity checks can.
{{ config(materialized='table', tags=['maxcompute']) }}
select case when date_day = timestamp'2000-01-02 00:00:00'
            then timestamp'2000-01-01 12:00:00'
            else date_day end as date_day
from {{ ref('mc_spine_10001') }}
