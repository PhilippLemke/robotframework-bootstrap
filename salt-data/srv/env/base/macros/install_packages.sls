{% macro install_greenshot(ver,install_source) %}
  '{{ ver }}':
    full_name: 'Greenshot {{ ver }}'
    installer: '{{ install_source }}/Greenshot-INSTALLER-{{ ver }}-RELEASE.exe'
    install_flags: '/verysilent'
    uninstaller: '%ProgramFiles%/Greenshot/unins000.exe'
    uninstall_flags: '/verysilent'
    msiexec: False
    locale: en_US
    reboot: False
{% endmacro %}
