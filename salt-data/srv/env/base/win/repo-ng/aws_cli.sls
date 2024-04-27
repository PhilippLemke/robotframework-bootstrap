{% from "macros/install_packages.sls" import install_aws_cli with context %}

{% set software = 'aws_cli' %}
{% set install_source = 'https://awscli.amazonaws.com' %}
{% set sw_versions = salt['pillar.get']('repo-ng-versions:' ~ software, ["Version not defined in pillar"]) %}

{{ software }}:
  {% for ver in sw_versions %}
  {{ install_aws_cli(ver, install_source) }}
  {% endfor %}