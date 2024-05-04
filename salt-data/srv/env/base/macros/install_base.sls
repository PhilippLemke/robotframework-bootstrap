{% macro s3_install(software) -%}
{% set protocol = 's3' %}
{% set s3_bucket = salt['pillar.get']('s3_bucket', 'specify s3_bucket in pillars') %}
{% set subfolder = 'blobs/' ~ software %}
{{- protocol ~ '://' ~ s3_bucket ~ '/' ~ subfolder -}}
{%- endmacro %}

{% macro local_install(software) -%}
{% set protocol = 'salt' %}
{% set subfolder = 'blobs/' ~ software %}
{{- protocol ~ '://' ~ subfolder -}}
{%- endmacro %}

{% macro app_install(app, version) -%}
app-inst-{{app}}:
  pkg.installed:
    - name: {{ app }}
    - version: {{ version }}
    - refresh: True
{%- endmacro %}

