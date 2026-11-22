-- Contract assertion for the MaxCompute macros; it returns one row per violated expectation,
-- so a clean run means every compared column matched.
select * from (
    select 'fiscal_quarter_number' as column_name, count(*) as mismatching_rows
    from {{ ref('mc_fiscal_periods_summary') }} a
    join {{ ref('mc_expected_fiscal_periods') }} e
      on a.fiscal_year_number = e.fiscal_year_number and a.fiscal_period_number = e.fiscal_period_number
    where coalesce(cast(a.fiscal_quarter_number as string), '<null>') <> coalesce(cast(e.fiscal_quarter_number as string), '<null>')
    union all
    select 'fiscal_period_of_quarter' as column_name, count(*) as mismatching_rows
    from {{ ref('mc_fiscal_periods_summary') }} a
    join {{ ref('mc_expected_fiscal_periods') }} e
      on a.fiscal_year_number = e.fiscal_year_number and a.fiscal_period_number = e.fiscal_period_number
    where coalesce(cast(a.fiscal_period_of_quarter as string), '<null>') <> coalesce(cast(e.fiscal_period_of_quarter as string), '<null>')
    union all
    select 'period_start_date' as column_name, count(*) as mismatching_rows
    from {{ ref('mc_fiscal_periods_summary') }} a
    join {{ ref('mc_expected_fiscal_periods') }} e
      on a.fiscal_year_number = e.fiscal_year_number and a.fiscal_period_number = e.fiscal_period_number
    where coalesce(cast(a.period_start_date as string), '<null>') <> coalesce(cast(e.period_start_date as string), '<null>')
    union all
    select 'period_end_date' as column_name, count(*) as mismatching_rows
    from {{ ref('mc_fiscal_periods_summary') }} a
    join {{ ref('mc_expected_fiscal_periods') }} e
      on a.fiscal_year_number = e.fiscal_year_number and a.fiscal_period_number = e.fiscal_period_number
    where coalesce(cast(a.period_end_date as string), '<null>') <> coalesce(cast(e.period_end_date as string), '<null>')
    union all
    select 'weeks_in_period' as column_name, count(*) as mismatching_rows
    from {{ ref('mc_fiscal_periods_summary') }} a
    join {{ ref('mc_expected_fiscal_periods') }} e
      on a.fiscal_year_number = e.fiscal_year_number and a.fiscal_period_number = e.fiscal_period_number
    where coalesce(cast(a.weeks_in_period as string), '<null>') <> coalesce(cast(e.weeks_in_period as string), '<null>')
    union all
    select 'max_week_of_period' as column_name, count(*) as mismatching_rows
    from {{ ref('mc_fiscal_periods_summary') }} a
    join {{ ref('mc_expected_fiscal_periods') }} e
      on a.fiscal_year_number = e.fiscal_year_number and a.fiscal_period_number = e.fiscal_period_number
    where coalesce(cast(a.max_week_of_period as string), '<null>') <> coalesce(cast(e.max_week_of_period as string), '<null>')
    union all
    select 'days_outside_range' as column_name, count(*) as mismatching_rows
    from {{ ref('mc_fiscal_periods') }}
    where date_day < date'2025-02-02' or date_day > date'2027-01-30'
    union all
    -- day_count moved into mc_day_count_violations() so the empty-model case is a violation
    -- row (see the macro's comment) and so mc_assert_negative_controls can drive it with a
    -- deliberately empty copy. The old inline branch reported the measured count in the
    -- violation column, which the outer `where mismatching_rows > 0` filter threw away at n=0.
    select 'day_count' as column_name, 1 as mismatching_rows
    from ( {{ mc_day_count_violations('mc_fiscal_periods', ref('mc_fiscal_periods'), 728) }} ) v
    union all
    select 'duplicate_days' as column_name, count(*) as mismatching_rows
    from (select date_day from {{ ref('mc_fiscal_periods') }}
          group by date_day having count(*) > 1) d
    union all
    select 'unexpected_fy' as column_name, count(*) as mismatching_rows
    from (select distinct fiscal_year_number from {{ ref('mc_fiscal_years') }}) f
    where fiscal_year_number not in (2025, 2026)
    union all
    -- Keyed period-set validation: every expected (fiscal_year_number, fiscal_period_number)
    -- must be present, and nothing extra may appear. Column-by-column comparisons join on
    -- that key, so a missing key silently vanished from them before this existed.
    select 'period_key_missing' as column_name, count(*) as mismatching_rows
    from {{ ref('mc_expected_fiscal_periods') }} e
    left join (
        select distinct fiscal_year_number, fiscal_period_number
        from {{ ref('mc_fiscal_periods_summary') }}
    ) a on a.fiscal_year_number = e.fiscal_year_number and a.fiscal_period_number = e.fiscal_period_number
    where a.fiscal_year_number is null
    union all
    select 'period_key_unexpected' as column_name, count(*) as mismatching_rows
    from (
        select distinct fiscal_year_number, fiscal_period_number
        from {{ ref('mc_fiscal_periods_summary') }}
    ) a
    left join {{ ref('mc_expected_fiscal_periods') }} e
      on a.fiscal_year_number = e.fiscal_year_number and a.fiscal_period_number = e.fiscal_period_number
    where e.fiscal_year_number is null

    union all
    select 'period_key_split' as column_name, count(*) as mismatching_rows
    from (select fiscal_year_number, fiscal_period_number from {{ ref('mc_fiscal_periods_summary') }}
          group by fiscal_year_number, fiscal_period_number
          having count(distinct fiscal_quarter_number) > 1 or count(distinct fiscal_period_of_quarter) > 1) k
) u
where mismatching_rows > 0
