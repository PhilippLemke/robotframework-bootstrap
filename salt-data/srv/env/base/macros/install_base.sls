{% macro s3_install(software) -%}
{% set protocol = 's3' %}
{% set s3_bucket = salt['config.get']('s3.bucket', 'specify s3_bucket in pillars') %}
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

{% macro vscode_local_extension_install(vscode_extensions, vscode_extension_source_dir) -%}
{% for ext in vscode_extensions -%}
{% set parts = ext.split('@') %}
{% set ext = parts[0] %}
{% set version = parts[1] if parts|length > 1 else None %}
{% if not version %}
version-for-vscode-ext-{{ ext }}:
  test.configurable_test_state:
    - name: undefined
    - changes: False
    - result: False
    - comment: Please define version in pillar, that is necessary for cloud or local install
# end if not version
{% endif %}
local-install-vscode-ext-{{ ext }}:
  vscode.extension_installed:
    - name: {{ ext }}
    - install_path: {{ vscode_extension_source_dir }}
    - version: {{ version }}
{% endfor %}
{%- endmacro %}


