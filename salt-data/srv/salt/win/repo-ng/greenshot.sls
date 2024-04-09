{% set install_mode = salt['pillar.get']('install-mode', 'online') %}
{% set s3_bucket = salt['pillar.get']('s3_bucket', 'specify s3_bucket in pillars') %}
{% set subfolder = 'blobs/greenshot' %}


{% set EXE_VERSIONS = [ '1.2.10.6' ] %}

greenshot:
  {% for VER in EXE_VERSIONS %}
 
    {% if install_mode == 'online' %}
    {% set install_source = 'https://github.com/greenshot/greenshot/releases/download/Greenshot-RELEASE-'+ VER  %}
    
    {% elif install_mode == 'cloud' %}
    {% set install_source = 's3://' + s3_bucket + '/' + subfolder %}
    
    {% elif install_mode == 'offline' %}
    {% set install_source = 'salt://' + subfolder %}
    
    {% endif %}
 
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
