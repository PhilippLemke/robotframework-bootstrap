{% from "macros/install_packages.sls" import install_aws-cli with context %}
{% from "macros/install_base.sls" import local_install with context %}

{% set software = 'aws-cli' %}
{% set sw_versions = salt['pillar.get']('repo-ng-versions:' ~ software, ["Version not defined in pillar"]) %}
{% set install_source = local_install(software) %}


{{ software }}:
  {% for ver in sw_versions %}
  {{ install_aws-cli(ver, install_source) }}
  {% endfor %}