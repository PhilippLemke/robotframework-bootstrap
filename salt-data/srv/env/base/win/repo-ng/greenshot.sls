{% from "macros/install_packages.sls" import install_greenshot with context %}

{% set software = 'greenshot' %}
{% set install_source = 'https://github.com/greenshot/greenshot/releases/download' %}
{% set sw_versions = salt['pillar.get']('repo-ng-versions:' ~ software, ["Version not defined in pillar"]) %}

{{ software }}:
  {% for ver in sw_versions %}
  {% set install_source_ver = install_source ~ '/Greenshot-RELEASE-' ~ ver %}
  {{ install_greenshot(ver, install_source_ver) }}
  {% endfor %}