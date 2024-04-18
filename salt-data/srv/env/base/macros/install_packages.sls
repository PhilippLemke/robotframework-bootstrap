{% macro s3_install_base(software) %}
{% from "macros/install_packages.sls" import install_software with context %}
{% set sw_versions = salt['pillar.get']('repo-ng-versions:' ~ software, ["Version not defined in pillar"]) %}

{% set protocol = 's3' %}
{% set s3_bucket = salt['pillar.get']('s3_bucket', 'specify s3_bucket in pillars') %}
{% set subfolder = 'blobs/' ~ software %}
{% set install_source = protocol ~ '://' ~ s3_bucket ~ '/' ~ subfolder %}

{{ software }}:
  {% for ver in sw_versions %}
  {{ install_software(ver, install_source) }}
  {% endfor %}
{% endmacro %}


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
  '{{ ver }}':
    full_name: 'Node.js'
    installer: {{ install_source }}/node-v{{ ver }}-x64.msi
    install_flags: '/qn /norestart'
    uninstall_flags: /qn /norestart
    msiexec: True
    locale: en_US
    reboot: False
{% endmacro %}

{% macro install_python3_x64(ver, install_source) %}
  '{{ ver }}150.0':
    full_name: 'Python {{ ver }} Core Interpreter (64-bit)'
    installer: {{ install_source }}/python-{{ ver }}-amd64.exe
    install_flags: '/quiet InstallAllUsers=1'
    uninstaller: {{ install_source }}/python-{{ ver }}-amd64.exe
    uninstall_flags: '/quiet /uninstall'
    msiexec: False
    locale: en_US
    reboot: False
{% endmacro %}

{% macro install_vscode(ver, install_source) %}
  '{{ ver }}':
    full_name: 'Microsoft Visual Studio Code'
    installer: {{ install_source }}/VSCodeSetup-x64-{{ ver }}.exe
    uninstaller: '{{ PROGRAM_FILES }}\Microsoft VS Code\unins000.exe'
    install_flags: '/SP- /VERYSILENT /NORESTART /MERGETASKS="!RUNCODE,ADDCONTEXTMENUFILES,ADDCONTEXTMENUFOLDERS,ADDTOPATH"'
    uninstall_flags: '/VERYSILENT /NORESTART'
    msiexec: False
    locale: en_US
    reboot: False

{% endmacro %}