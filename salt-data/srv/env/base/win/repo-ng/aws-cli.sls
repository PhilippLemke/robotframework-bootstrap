{% from "macros/install_packages.sls" import install_firefox with context %}
{% set sw_versions = salt['pillar.get']('repo-ng-versions:aws-cli',["Version not defined in pillar"] ) %}

firefox:
  {% for ver in sw_versions %}
    {% set install_source = 'https://awscli.amazonaws.com/AWSCLIV2-' ~ ver ~ '.msi'  %}
    {{ install_firefox(ver, install_source) }}
  {% endfor %}

