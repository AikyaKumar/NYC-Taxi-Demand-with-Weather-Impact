-- macros/custom_generate_schema_name.sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {#-
        THIS MACRO IS CRITICAL - It prevents dbt from adding project prefix
        Without this, dbt will create: dm2_aikya_raw_dm2_aikya_stg
        With this, dbt will create: dm2_aikya_stg
    -#}
    
    {%- set default_schema = target.schema -%}
    
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}

{%- endmacro %}