{% from "macros/install_packages.sls" import install_greenshot with context %}
{% set sw_versions = salt['pillar.get']('repo-ng-versions:firefox',["Version not defined in pillar"] ) %}

firefox:
  {% for ver in sw_versions %}
    {% set install_source = 'https://download-installer.cdn.mozilla.net/pub/firefox/releases/' + ver +'/win64'  %}
    {{ install_firefox(ver, install_source)}}
  {% endfor %}

