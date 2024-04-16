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

{% macro install_firefox(ver, install_source) %}
{% set lang = 'en-US' %}
  '{{ ver }}':
    full_name: 'Mozilla Firefox (x64 {{ lang }})'
    installer: {{ install_source }}/{{ lang }}/Firefox%20Setup%20{{ ver }}.exe
    install_flags: '/S'
    uninstaller: '%ProgramFiles%\Mozilla Firefox\uninstall\helper.exe'
    uninstall_flags: '/S'
    msiexec: False
    locale: en_US
    reboot: False
{% endmacro %}

{% macro install_nodejs(ver, install_source) %}
{% endmacro %}

{% macro install_python3_x64(ver, install_source) %}
{% endmacro %}

{% macro install_vscode(ver, install_source) %}
{% endmacro %}