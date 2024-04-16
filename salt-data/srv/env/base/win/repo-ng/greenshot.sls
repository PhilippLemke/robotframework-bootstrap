{% from "macros/install_packages.sls" import install_greenshot with context %}
{% set sw_versions = salt['pillar.get']('repo-ng-versions:greenshot',["Version not defined in pillar"] ) %}

greenshot:
  {% for ver in sw_versions %}
    {% set install_source = 'https://github.com/greenshot/greenshot/releases/download/Greenshot-RELEASE-'+ ver  %}
 
  {{ install_greenshot(ver, install_source)}}
  {% endfor %}