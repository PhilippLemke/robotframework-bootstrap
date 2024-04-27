{% from "macros/install_packages.sls" import install_firefox with context %}

{% set software = 'firefox' %}
{% set install_source = 'https://download-installer.cdn.mozilla.net/pub/firefox/releases/' %}
{% set sw_versions = salt['pillar.get']('repo-ng-versions:' ~ software, ["Version not defined in pillar"]) %}

{{ software }}:
  {% for ver in sw_versions %}
  {% set install_source_ver = install_source ~ ver ~ '/win64' %}
  {{ install_firefox(ver, install_source_ver) }}
  {% endfor %}
