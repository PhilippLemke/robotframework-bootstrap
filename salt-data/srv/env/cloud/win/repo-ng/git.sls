{% from "macros/install_packages.sls" import install_git with context %}
{% from "macros/install_base.sls" import s3_install with context %}

{% set software = 'git' %}
{% set sw_versions = salt['pillar.get']('repo-ng-versions:' ~ software, ["Version not defined in pillar"]) %}
{% set install_source = s3_install(software) %}


{{ software }}:
  {% for ver in sw_versions %}
  {{ install_git(ver, install_source) }}
  {% endfor %}