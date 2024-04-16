{% from "macros/install_packages.sls" import install_greenshot with context %}

#{% set EXE_VERSIONS = [ '1.2.10.6' ] %}

{% set sw_versions = salt['pillar.get']('repo-ng-versions:greenshot') %}
greenshot:
  {% for ver in sw_versions %}
    {% set install_source = 'https://github.com/greenshot/greenshot/releases/download/Greenshot-RELEASE-'+ ver  %}
 
  {{ install_greenshot(ver, install_source)}}
  {% endfor %}