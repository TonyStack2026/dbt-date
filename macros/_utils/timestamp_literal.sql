{%- macro maxcompute_timestamp_literal(value) -%}
    {#-
      MaxCompute only accepts TIMESTAMP literals in the full 'yyyy-mm-dd hh:mm:ss' form.
      A date-only literal (timestamp'2026-01-01') fails at parse time with
      ODPS-0130161 "invalid TIMESTAMP format", and the tempting workaround
      cast('2026-01-01' as timestamp) is worse: the server does not raise, it
      silently returns NULL, so an entire date spine becomes NULL rows.
      Normalise every accepted input here and refuse the ambiguous ones at compile
      time instead of handing a silent NULL to the user.
    -#}
    {%- if value is string -%}
        {%- set text = value | trim -%}
        {%- if (text | length) == 10 -%}
            {{ return(text ~ ' 00:00:00') }}
        {%- elif (text | length) >= 19 and text[10:11] in [' ', 'T'] -%}
            {{ return(text[:19]) }}
        {%- else -%}
            {{ exceptions.raise_compiler_error(
                "dbt_date could not read the date '" ~ value ~ "'. On MaxCompute pass a date as 'yyyy-mm-dd' "
                ~ "or a timestamp as 'yyyy-mm-dd hh:mm:ss' (the server rejects date-only TIMESTAMP literals "
                ~ "and silently casts them to NULL).")
            }}
        {%- endif -%}
    {%- else -%}
        {{ return(value.strftime('%Y-%m-%d %H:%M:%S')) }}
    {%- endif -%}
{%- endmacro -%}
