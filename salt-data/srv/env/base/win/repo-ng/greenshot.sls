{% from "macros/custom_macros.sls" import install_greenshot with context %}

{% set EXE_VERSIONS = [ '1.2.10.6' ] %}

greenshot:
  {% for VER in EXE_VERSIONS %}
    {% set install_source = 'https://github.com/greenshot/greenshot/releases/download/Greenshot-RELEASE-'+ VER  %}
 
  {{ install_greenshot(VER, install_source)}}
  {% endfor %}
