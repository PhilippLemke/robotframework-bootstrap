{% from "macros/install_packages.sls" import install_nodejs with context %}
{% from "macros/install_base.sls" import local_install with context %}

{% set software = 'nodejs' %}
{% set sw_versions = salt['pillar.get']('repo-ng-versions:' ~ software, ["Version not defined in pillar"]) %}
{% set install_source = local_install(software) %}


{{ software }}:
  {% for ver in sw_versions %}
  {{ install_nodejs(ver, install_source) }}
  {% endfor %}