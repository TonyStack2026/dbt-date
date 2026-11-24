-- Same 10,001-row span as mc_spine_10001, but built with the documented default limit actually
-- enforced on the statements this model runs: odps.sql.max.sequence.length=10000 via the adapter's
-- model-level `sql_hints` (dbt/adapters/maxcompute/impl.py merges `configs['sql_hints']` into the
-- hints of that model's statements). Without this the green build only proves the row set on a
-- project whose effective default sits above 10,000 -- which is exactly the gap the review named.
--
-- Expected: the chunked row source builds (each chunk is exactly 10,000 / 1 elements, both at or
-- below the enforced cap) and the membership assertion passes. The paired negative control -- the
-- old single-array shape under this same hint -- is a one-off measurement, not a committed model,
-- because a permanently failing model is not a test; its reading is in this item's evidence.
{{ config(materialized='table', tags=['maxcompute'],
          sql_hints={'odps.sql.max.sequence.length': '10000'}) }}
{{ dbt_date.get_base_dates(start_date='2000-01-01', end_date='2027-05-20', datepart='day') }}
