{% from "macros/install_packages.sls" import install_python3_x64 with context %}

{% set software = 'python3_x64' %}
{% set install_source = 'https://www.python.org/ftp/python/' %}
{% set sw_versions = salt['pillar.get']('repo-ng-versions:' ~ software, ["Version not defined in pillar"]) %}

{{ software }}:
  {% for ver in sw_versions %}
  {% set install_source_ver = install_source ~ ver  %}
  {{ install_python3_x64(ver, install_source_ver) }}
  {% endfor %}
