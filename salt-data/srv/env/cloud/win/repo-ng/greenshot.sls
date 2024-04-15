{% set protocol = 's3' %}
{% set s3_bucket = salt['pillar.get']('s3_bucket', 'specify s3_bucket in pillars') %}
{% set subfolder = 'blobs/greenshot' %}
{% set install_source = protocol + '://' + s3_bucket + '/' + subfolder %}


{% set EXE_VERSIONS = [ '1.2.10.6' ] %}

greenshot:
  {% for VER in EXE_VERSIONS %}
  '{{ VER }}':
    full_name: 'Greenshot {{ VER }}'
    installer: '{{ install_source }}/Greenshot-INSTALLER-{{ VER }}-RELEASE.exe'
    install_flags: '/verysilent'
    uninstaller: '%ProgramFiles%/Greenshot/unins000.exe'
    uninstall_flags: '/verysilent'
    msiexec: False
    locale: en_US
    reboot: False
  {% endfor %}
