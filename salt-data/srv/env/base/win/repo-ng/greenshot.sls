{% set EXE_VERSIONS = [ '1.2.10.6' ] %}

greenshot:
  {% for VER in EXE_VERSIONS %}
    {% set install_source = 'https://github.com/greenshot/greenshot/releases/download/Greenshot-RELEASE-'+ VER  %}
 
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
