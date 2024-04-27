{% from "macros/install_packages.sls" import install_nodejs with context %}

{% set software = 'nodejs' %}
{% set install_source = 'https://nodejs.org/dist' %}
{% set sw_versions = salt['pillar.get']('repo-ng-versions:' ~ software, ["Version not defined in pillar"]) %}

{{ software }}:
  {% for ver in sw_versions %}
  {% set install_source_ver = install_source ~ '/v' ~ ver %}
  {{ install_nodejs(ver, install_source_ver) }}
  {% endfor %}