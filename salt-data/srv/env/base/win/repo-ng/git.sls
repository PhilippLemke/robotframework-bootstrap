{% from "macros/install_packages.sls" import install_git with context %}

{% set software = 'git' %}
{% set install_source = 'https://github.com/git-for-windows/git/releases/download' %}
{% set sw_versions = salt['pillar.get']('repo-ng-versions:' ~ software, ["Version not defined in pillar"]) %}

{{ software }}:
  {% for ver in sw_versions %}
  {{ install_git(ver, install_source) }}
  {% endfor %}