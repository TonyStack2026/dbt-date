-- Contract assertion for convert_timezone() shifts on MaxCompute.
-- The comparison lives in mc_shift_violations() so that mc_assert_negative_controls can run
-- the identical logic against a broken input. Previous shape here was an inner join with a
-- bare `<>`, which silently passed when an expected case_id was missing from the model and
-- when actual_shift_seconds came back NULL -- both are violations, and both are now reported.
{{ mc_shift_violations('mc_timezone_shifts', ref('mc_timezone_shifts'), mc_timezone_shift_cases()) }}
