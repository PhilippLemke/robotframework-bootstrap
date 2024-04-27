{% from "macros/install_packages.sls" import install_aws_cli with context %}
{% from "macros/install_base.sls" import s3_install with context %}

{% set software = 'aws_cli' %}
{% set sw_versions = salt['pillar.get']('repo-ng-versions:' ~ software, ["Version not defined in pillar"]) %}
{% set install_source = s3_install(software) %}


{{ software }}:
  {% for ver in sw_versions %}
  {{ install_aws_cli(ver, install_source) }}
  {% endfor %}