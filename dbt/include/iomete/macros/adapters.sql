{% macro file_format_clause() %}
  {%- set file_format = config.get('file_format', validator=validation.any[basestring]) -%}
  {%- if file_format is not none %}
    using {{ file_format }}
  {%- endif %}
{%- endmacro -%}

{% macro location_clause() %}
  {%- set location_root = config.get('location_root', validator=validation.any[basestring]) -%}
  {%- set identifier = model['alias'] -%}
  {%- if location_root is not none %}
    location '{{ location_root }}/{{ identifier }}'
  {%- endif %}
{%- endmacro -%}

{% macro options_clause() -%}
  {%- set options = config.get('options') -%}
  {%- if options is not none %}
    options (
      {%- for option in options -%}
      {{ option }} "{{ options[option] }}" {% if not loop.last %}, {% endif %}
      {%- endfor %}
    )
  {%- endif %}
{%- endmacro -%}

{% macro comment_clause() %}
  {%- set raw_persist_docs = config.get('persist_docs', {}) -%}

  {%- if raw_persist_docs is mapping -%}
    {%- set raw_relation = raw_persist_docs.get('relation', false) -%}
      {%- if raw_relation -%}
      comment '{{ model.description | replace("'", "\\'") }}'
      {% endif %}
  {%- elif raw_persist_docs -%}
    {{ exceptions.raise_compiler_error("Invalid value provided for 'persist_docs'. Expected dict but got value: " ~ raw_persist_docs) }}
  {% endif %}
{%- endmacro -%}

{% macro partition_cols(label, required=false) %}
  {%- set cols = config.get('partition_by', validator=validation.any[list, basestring]) -%}
  {%- if cols is not none %}
    {%- if cols is string -%}
      {%- set cols = [cols] -%}
    {%- endif -%}
    {{ label }} (
    {%- for item in cols -%}
      {{ item }}
      {%- if not loop.last -%},{%- endif -%}
    {%- endfor -%}
    )
  {%- endif %}
{%- endmacro -%}


{% macro clustered_cols(label, required=false) %}
  {%- set cols = config.get('clustered_by', validator=validation.any[list, basestring]) -%}
  {%- set buckets = config.get('buckets', validator=validation.any[int]) -%}
  {%- if (cols is not none) and (buckets is not none) %}
    {%- if cols is string -%}
      {%- set cols = [cols] -%}
    {%- endif -%}
    {{ label }} (
    {%- for item in cols -%}
      {{ item }}
      {%- if not loop.last -%},{%- endif -%}
    {%- endfor -%}
    ) into {{ buckets }} buckets
  {%- endif %}
{%- endmacro -%}

{% macro fetch_tbl_properties(relation) -%}
  {% call statement('list_properties', fetch_result=True) -%}
    SHOW TBLPROPERTIES {{ relation }}
  {% endcall %}
  {% do return(load_result('list_properties').table) %}
{%- endmacro %}


{#-- We can't use temporary tables with `create ... as ()` syntax #}
{% macro create_temporary_view(relation, sql) -%}
  create temporary view {{ relation.include(schema=false) }} as
    {{ sql }}
{% endmacro %}

{% macro iomete__create_table_as(temporary, relation, sql) -%}

  {% if temporary -%}
    {{ create_temporary_view(relation, sql) }}
  {%- else -%}
    {%- set raw_file_format = config.get('file_format', default='iceberg') -%}
    {% set is_iceberg_file_format = raw_file_format == 'iceberg' %}

    {% if is_iceberg_file_format %}
      create or replace table {{ relation }}
    {% else %}
      create table {{ relation }}
    {% endif %}
    {{ file_format_clause() }}
    {{ options_clause() }}
    {{ partition_cols(label="partitioned by") }}
    {{ clustered_cols(label="clustered by") }}
    {{ location_clause() }}
    {{ comment_clause() }}
    as
      {{ sql }}
  {%- endif %}
{%- endmacro -%}


{% macro iomete__create_view_as(relation, sql) -%}
  create or replace view {{ relation }}
  {{ comment_clause() }}
  as
    {{ sql }}
{% endmacro %}

{% macro iomete__create_schema(relation) -%}
  {%- call statement('create_schema') -%}
    create schema if not exists {{relation}}
  {% endcall %}
{% endmacro %}

{% macro iomete__drop_schema(relation) -%}
  {%- call statement('drop_schema') -%}
    drop schema if exists {{ relation }} cascade
  {%- endcall -%}
{% endmacro %}

{% macro iomete__get_columns_in_relation(relation) -%}
  {% call statement('get_columns_in_relation', fetch_result=True) %}
      describe extended {{ relation.include(schema=(schema is not none)) }}
  {% endcall %}
  {% do return(load_result('get_columns_in_relation').table) %}
{% endmacro %}

{% macro iomete__list_relations_without_caching(relation) %}
  {% call statement('list_relations_without_caching', fetch_result=True) -%}
    show tables in {{ relation }} like '*'
  {% endcall %}

  {% do return(load_result('list_relations_without_caching').table) %}
{% endmacro %}



{% macro list_all_relations_without_caching(schema_relation) %}
  {% call statement('list_all_relations_without_caching', fetch_result=True) -%}
    show tables in {{ schema_relation }} like '*'
  {% endcall %}

  {% do return(load_result('list_all_relations_without_caching').table) %}
{% endmacro %}

{% macro list_views_relations_without_caching(schema_relation) %}
  {% call statement('list_views_relations_without_caching', fetch_result=True) -%}
    show views in {{ schema_relation }} like '*'
  {% endcall %}

  {% do return(load_result('list_views_relations_without_caching').table) %}
{% endmacro %}

{% macro describe_table(relation) -%}
  {% call statement('describe_table', fetch_result=True) %}
      describe extended {{ relation.include(schema=(schema is not none)) }}
  {% endcall %}
  {% do return(load_result('describe_table').table) %}
{% endmacro %}

{% macro iomete__list_schemas(database) -%}
  {% call statement('list_schemas', fetch_result=True, auto_begin=False) %}
    show databases
  {% endcall %}
  {{ return(load_result('list_schemas').table) }}
{% endmacro %}

{% macro iomete__current_timestamp() -%}
  current_timestamp()
{%- endmacro %}

{% macro iomete__rename_relation(from_relation, to_relation) -%}
  {% call statement('rename_relation') -%}
    {% if not from_relation.type %}
      {% do exceptions.raise_database_error("Cannot rename a relation with a blank type: " ~ from_relation.identifier) %}
    {% elif from_relation.type in ('table') %}
        alter table {{ from_relation }} rename to {{ to_relation }}
    {% elif from_relation.type == 'view' %}
        alter view {{ from_relation }} rename to {{ to_relation }}
    {% else %}
      {% do exceptions.raise_database_error("Unknown type '" ~ from_relation.type ~ "' for relation: " ~ from_relation.identifier) %}
    {% endif %}
  {%- endcall %}
{% endmacro %}

{% macro iomete__drop_relation(relation) -%}
  {% call statement('drop_relation', auto_begin=False) -%}
    drop {{ relation.type }} if exists {{ relation }}
  {%- endcall %}
{% endmacro %}


{% macro iomete__generate_database_name(custom_database_name=none, node=none) -%}
  {% do return(None) %}
{%- endmacro %}

{% macro iomete__persist_docs(relation, model, for_relation, for_columns) -%}
  {% if for_columns and config.persist_column_docs() and model.columns %}
    {% do alter_column_comment(relation, model.columns) %}
  {% endif %}
{% endmacro %}

{% macro iomete__alter_column_comment(relation, column_dict) %}
  {%- set raw_file_format = config.get('file_format', default='iceberg') -%}
  {% set is_iceberg_file_format = raw_file_format == 'iceberg' %}

  {% if is_iceberg_file_format %}
    {% for column_name in column_dict %}
      {% set comment = column_dict[column_name]['description'] %}
      {% set escaped_comment = comment | replace('\'', '\\\'') %}
      {% set comment_query %}
        alter table {{ relation }} change column 
            {{ adapter.quote(column_name) if column_dict[column_name]['quote'] else column_name }}
            comment '{{ escaped_comment }}';
      {% endset %}
      {% do run_query(comment_query) %}
    {% endfor %}
  {% endif %}
{% endmacro %}


{% macro iomete__make_temp_relation(base_relation, suffix) %}
    {% set tmp_identifier = base_relation.identifier ~ suffix %}
    {% set tmp_relation = base_relation.incorporate(path = {
        "identifier": tmp_identifier,
        "schema": None
    }) -%}

    {% do return(tmp_relation) %}
{% endmacro %}


{% macro iomete__alter_column_type(relation, column_name, new_column_type) -%}
  {% call statement('alter_column_type') %}
    alter table {{ relation }} alter column {{ column_name }} type {{ new_column_type }};
  {% endcall %}
{% endmacro %}


{% macro iomete__alter_relation_add_remove_columns(relation, add_columns, remove_columns) %}
  
  {% if remove_columns %}
        {% set sql -%}
            alter {{ relation.type }} {{ relation }} drop column
            {% for column in remove_columns %}
               {{ column.name }}{{ ',' if not loop.last }}
            {% endfor %}
        {%- endset -%}

        {% do run_query(sql) %}
  {% endif %}
  
  {% if add_columns is none %}
    {% set add_columns = [] %}
  {% endif %}
  
  {% set sql -%}
     
     alter {{ relation.type }} {{ relation }}
       
       {% if add_columns %} add columns {% endif %}
            {% for column in add_columns %}
               {{ column.name }} {{ column.data_type }}{{ ',' if not loop.last }}
            {% endfor %}
  
  {%- endset -%}

  {% do run_query(sql) %}

{% endmacro %}
