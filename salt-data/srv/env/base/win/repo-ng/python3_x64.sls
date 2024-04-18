{% from "macros/install_packages.sls" import install_python3_x64 with context %}
{% set sw_versions = salt['pillar.get']('repo-ng-versions:python3_x64',["Version not defined in pillar"] ) %}

python3_x64:
  {% for ver in sw_versions %}
    {% set install_source = 'https://www.python.org/ftp/python/' + ver  %}
    {{ install_python3_x64(ver, install_source) }}
  {% endfor %}

