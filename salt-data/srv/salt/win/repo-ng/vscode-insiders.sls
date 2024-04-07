{% set PROGRAM_FILES = "%ProgramFiles%" %}
{% set VERSIONS = ['1.74.0'] %}

vscode-insider:
  {% for version in VERSIONS %}
  '{{version}}':
    full_name: 'Microsoft Visual Studio Code Insiders'
    installer: 'salt://blobs/vscode-insider/VSCodeSetup-x64-{{ version }}-insider.exe'
    uninstaller: '{{ PROGRAM_FILES }}\Microsoft VS Code Insiders\unins000.exe'
    install_flags: '/SP- /VERYSILENT /NORESTART /MERGETASKS="!RUNCODE,ADDCONTEXTMENUFILES,ADDCONTEXTMENUFOLDERS,ADDTOPATH"'
    uninstall_flags: '/VERYSILENT /NORESTART'
    msiexec: False
    locale: en_US
    reboot: False
  {% endfor %}
