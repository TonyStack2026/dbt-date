-- Spans at and around MaxCompute's documented default sequence() cap (10,000 elements per call:
-- https://www.alibabacloud.com/help/en/maxcompute/sequence-1), built through the real dbt path.
--
-- Four cases: 9,999 / 10,000 / 10,001 daily rows from 2000-01-01 with the end-exclusive bounds
-- 2027-05-18 / 19 / 20, and the same 10,001-row span rebuilt with odps.sql.max.sequence.length
-- pinned to 10,000 (mc_spine_10001_capped) so the green result is not an artefact of a project
-- default that happens to sit higher. Membership is asserted by mc_spine_membership_violations:
-- row count, distinct timestamps, distinct calendar days, non-midnight rows, both endpoints and
-- the server-measured window width -- the review's shifted-row counter-example is what forced
-- the two day-identity checks, and mc_assert_negative_controls drives it through the same macro.
-- The repo's maxcompute target sets no odps.* flag, so the first three cases run under the
-- project default; only the capped case pins it.
{{ mc_spine_membership_violations('spine_9999', ref('mc_spine_9999'), 9999, '2000-01-01 00:00:00', '2027-05-17 00:00:00') }}

union all

{{ mc_spine_membership_violations('spine_10000', ref('mc_spine_10000'), 10000, '2000-01-01 00:00:00', '2027-05-18 00:00:00') }}

union all

{{ mc_spine_membership_violations('spine_10001', ref('mc_spine_10001'), 10001, '2000-01-01 00:00:00', '2027-05-19 00:00:00') }}

union all

{{ mc_spine_membership_violations('spine_10001_capped', ref('mc_spine_10001_capped'), 10001, '2000-01-01 00:00:00', '2027-05-19 00:00:00') }}
