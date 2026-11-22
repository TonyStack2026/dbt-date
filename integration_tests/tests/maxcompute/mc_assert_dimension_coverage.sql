-- Coverage assertions for the fixed-window date dimensions.
--
-- Two layers, deliberately separate because they catch different corruption:
--   * mc_date_shape_violations -- row count and min .. max. Cheap, catches a shifted or
--     short window (this is the check that caught the 11-05 off-by-one endpoint).
--   * mc_date_key_violations   -- per-date multiplicity. Catches what the shape check cannot:
--     an interior day dropped while another is duplicated leaves count, min and max identical.
-- mc_assert_negative_controls feeds a corruption of exactly that second kind through both
-- layers and requires shape=0 / multiplicity=2, so neither layer is decorative.
{{ mc_date_shape_violations('cross_year', ref('mc_date_dimension_cross_year'), ref('mc_expected_date_dimension_cross_year')) }}

union all

{{ mc_date_key_violations('cross_year', ref('mc_date_dimension_cross_year'), ref('mc_expected_date_dimension_cross_year')) }}

union all

{{ mc_date_shape_violations('leap_day', ref('mc_date_dimension_leap_day'), ref('mc_expected_date_dimension_leap_day')) }}

union all

{{ mc_date_key_violations('leap_day', ref('mc_date_dimension_leap_day'), ref('mc_expected_date_dimension_leap_day')) }}

