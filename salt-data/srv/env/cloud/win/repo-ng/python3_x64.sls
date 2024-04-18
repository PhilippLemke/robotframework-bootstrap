{% from "macros/install_packages.sls" import install_python3_x64 with context %}
{% from "macros/install_base.sls" import s3_install with context %}

{% set software = 'python3_x64' %}
{% set sw_versions = salt['pillar.get']('repo-ng-versions:' ~ software, ["Version not defined in pillar"]) %}
{% set install_source = s3_install(software) %}


{{ software }}:
  {% for ver in sw_versions %}
  {{ install_python3_x64(ver, install_source) }}
  {% endfor %}