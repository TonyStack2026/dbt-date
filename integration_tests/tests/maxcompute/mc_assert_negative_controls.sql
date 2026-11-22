-- Non-vacuity controls. This test exists so that the contract tests cannot quietly become
-- decoration: each control feeds a deliberately broken input through the *same* comparison
-- logic the real assertions use (integration_tests/macros/mc_contract_checks.sql, and the same
-- case list via mc_timezone_shift_cases()) and requires an exact number of violations.
--
-- A row returned here means a guard stopped detecting the corruption it is supposed to detect.
with mc_tz_ctl as (
    select count(*) as detected
    from ( {{ mc_shift_violations('mc_tz_shifts_broken', ref('mc_tz_shifts_broken'), mc_timezone_shift_cases()) }} ) v
),
mc_tz_default_zone_ctl as (
    -- same control for the second timezone assertion, driving its own case list through the
    -- same macro the real assertion uses (a hand-written look-alike would prove nothing)
    select count(*) as detected
    from ( {{ mc_shift_violations('mc_tz_default_zone_broken', ref('mc_tz_default_zone_broken'), mc_timezone_default_zone_cases()) }} ) v
),
mc_day_count_ctl as (
    -- the corruption that used to pass: a fiscal model with zero distinct days
    select count(*) as detected
    from ( {{ mc_day_count_violations('mc_fiscal_periods_empty', ref('mc_fiscal_periods_empty'), 728) }} ) v
),
mc_day_count_good_ctl as (
    -- and its positive counterpart: on the real model the same check must stay silent
    select count(*) as detected
    from ( {{ mc_day_count_violations('mc_fiscal_periods', ref('mc_fiscal_periods'), 728) }} ) v
),
mc_shape_ctl as (
    select count(*) as detected
    from ( {{ mc_date_shape_violations('mc_date_dimension_broken', ref('mc_date_dimension_broken'), ref('mc_expected_date_dimension_cross_year')) }} ) v
),
mc_mult_ctl as (
    select count(*) as detected
    from ( {{ mc_date_key_violations('mc_date_dimension_broken', ref('mc_date_dimension_broken'), ref('mc_expected_date_dimension_cross_year')) }} ) v
),
mc_good_dim as (
    -- and the positive side: on the un-corrupted dimension the multiplicity layer must stay silent
    select count(*) as detected
    from ( {{ mc_date_key_violations('cross_year_clean', ref('mc_date_dimension_cross_year'), ref('mc_expected_date_dimension_cross_year')) }} ) v
)
select 'tz_shifts_control_detects_missing_key_and_null' as control_name,
       cast(detected as string) as detected, '2' as must_detect
from mc_tz_ctl where detected <> 2

union all

select 'default_zone_control_detects_one_missing_key', cast(detected as string), '1'
from mc_tz_default_zone_ctl where detected <> 1

union all

-- count/min/max must be blind to a dropped-interior-plus-duplicated pair; that blindness is
-- the reason the multiplicity layer was added, so pin it rather than assert it in prose.
select 'dim_shape_layer_is_blind_to_hole_plus_dup', cast(detected as string), '0'
from mc_shape_ctl where detected <> 0

union all

select 'dim_multiplicity_layer_catches_hole_plus_dup', cast(detected as string), '2'
from mc_mult_ctl where detected <> 2

union all

select 'dim_multiplicity_layer_is_quiet_on_good_dim', cast(detected as string), '0'
from mc_good_dim where detected <> 0

union all

select 'day_count_catches_empty_model', cast(detected as string), '1'
from mc_day_count_ctl where detected <> 1

union all

select 'day_count_is_quiet_on_real_model', cast(detected as string), '0'
from mc_day_count_good_ctl where detected <> 0
