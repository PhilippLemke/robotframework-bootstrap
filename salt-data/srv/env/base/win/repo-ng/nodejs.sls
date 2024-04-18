{% from "macros/install_packages.sls" import install_nodejs with context %}
{% set sw_versions = salt['pillar.get']('repo-ng-versions:nodejs',["Version not defined in pillar"] ) %}

nodejs:
  {% for ver in sw_versions %}
    {% set install_source = 'https://nodejs.org/dist/v{{ ver }}/node-v{{ ver }}-x64.msi'  %}
    {{ install_nodejs(ver, install_source) }}
  {% endfor %}




