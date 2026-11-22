-- Contract assertion for the project-default-timezone leg of convert_timezone().
-- Same reasoning as mc_assert_timezone_shifts: key-driven LEFT JOIN with explicit NULL
-- handling, shared with the negative control.
{{ mc_shift_violations('mc_timezone_default_zone', ref('mc_timezone_default_zone'), mc_timezone_default_zone_cases()) }}
