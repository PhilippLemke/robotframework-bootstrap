{% macro install_greenshot(VER,install_source) %}
  '{{ VER }}':
    full_name: 'Greenshot {{ VER }}'
    installer: '{{ install_source }}/Greenshot-INSTALLER-{{ VER }}-RELEASE.exe'
    install_flags: '/verysilent'
    uninstaller: '%ProgramFiles%/Greenshot/unins000.exe'
    uninstall_flags: '/verysilent'
    msiexec: False
    locale: en_US
    reboot: False
{% endmacro %}
