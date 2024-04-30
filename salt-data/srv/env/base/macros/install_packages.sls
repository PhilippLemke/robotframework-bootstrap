
{% macro install_aws_cli(ver, install_source) %}
  '{{ ver }}.0':
    full_name: 'AWS Command Line Interface v2'
    installer: {{ install_source|trim }}/AWSCLIV2-{{ ver }}.msi
    install_flags: '/qn /norestart'
    uninstall_flags: /qn /norestart
    msiexec: True
    locale: en_US
    reboot: False
{% endmacro %}

{% macro install_git(ver, install_source) %}
  '{{ ver }}':
    full_name: 'Git'
    #installer: {{ install_source|trim }}/Greenshot-INSTALLER-{{ ver }}-RELEASE.exe
    installer: {{ install_source|trim }}/v{{ ver }}/Git-{{ ver }}-64-bit.exe
    #https://github.com/git-for-windows/git/releases/download/v2.45.0.windows.1/Git-2.45.0-64-bit.exe
    #installer: https://github.com/git-for-windows/git/releases/download/v{{ extended_version }}/Git-{{ version }}-{{ arch }}-bit.exe
    # It is impossible to downgrade git silently. It will always pop a message
    # that will cause salt to hang. `/SUPPRESSMSGBOXES` will suppress that
    # warning allowing salt to continue, but the package will not downgrade
    install_flags: /VERYSILENT /NORESTART /SP- /NOCANCEL /SUPPRESSMSGBOXES
    uninstaller: forfiles
    uninstall_flags: '/p "%ProgramFiles%\Git" /m unins*.exe /c "cmd /c @path /VERYSILENT /NORESTART"'
    msiexec: False
    locale: en_US
    reboot: False
{% endmacro %}

{% macro install_greenshot(ver, install_source) %}
  '{{ ver }}':
    full_name: 'Greenshot {{ ver }}'
    installer: {{ install_source|trim }}/Greenshot-INSTALLER-{{ ver }}-RELEASE.exe
    install_flags: '/verysilent'
    uninstaller: '%ProgramFiles%/Greenshot/unins000.exe'
    uninstall_flags: '/verysilent'
    msiexec: False
    locale: en_US
    reboot: False
{% endmacro %}


{% macro install_firefox(ver, install_source) %}
{% set install_source = install_source|trim %}
{% set lang = 'en-US' %}
{%  set pkg = 'Firefox%20Setup%20' ~ ver ~ '.exe' %}
{% if not install_source.startswith('https') %}
  {% set pkg = pkg | replace("%20", " ") %}
{% endif %}
  '{{ ver }}':
    full_name: 'Mozilla Firefox (x64 {{ lang }})'
    installer: {{ install_source }}/{{ lang }}/{{ pkg }}
    install_flags: '/S'
    uninstaller: '%ProgramFiles%\Mozilla Firefox\uninstall\helper.exe'
    uninstall_flags: '/S'
    msiexec: False
    locale: en_US
    reboot: False
{% endmacro %}

{% macro install_nodejs(ver, install_source) %}
  '{{ ver }}':
    full_name: 'Node.js'
    installer: {{ install_source|trim }}/node-v{{ ver }}-x64.msi
    install_flags: '/qn /norestart'
    uninstall_flags: /qn /norestart
    msiexec: True
    locale: en_US
    reboot: False
{% endmacro %}

{% macro install_python3_x64(ver, install_source) %}
  '{{ ver }}150.0':
    full_name: 'Python {{ ver }} Core Interpreter (64-bit)'
    installer: {{ install_source|trim }}/python-{{ ver }}-amd64.exe
    install_flags: '/quiet InstallAllUsers=1'
    uninstaller: {{ install_source|trim }}/python-{{ ver }}-amd64.exe
    uninstall_flags: '/quiet /uninstall'
    msiexec: False
    locale: en_US
    reboot: False
{% endmacro %}

{% macro install_vscode(ver, install_source) %}
  {% set PROGRAM_FILES = "%ProgramFiles%" %}
  '{{ ver }}':
    full_name: 'Microsoft Visual Studio Code'
    installer: {{ install_source|trim }}/VSCodeSetup-x64-{{ ver }}.exe
    uninstaller: '{{ PROGRAM_FILES }}\Microsoft VS Code\unins000.exe'
    install_flags: '/SP- /VERYSILENT /NORESTART /MERGETASKS="!RUNCODE,ADDCONTEXTMENUFILES,ADDCONTEXTMENUFOLDERS,ADDTOPATH"'
    uninstall_flags: '/VERYSILENT /NORESTART'
    msiexec: False
    locale: en_US
    reboot: False
{% endmacro %}