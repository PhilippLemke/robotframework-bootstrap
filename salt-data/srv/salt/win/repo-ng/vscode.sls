# original source: https://github.com/saltstack/salt-winrepo-ng/blob/master/vscode.sls
# due to winrepo installer limitations you need to manually download x86 + x64 System installer from
# https://code.visualstudio.com/Download
# and put it on the winrepo on master to install it the 'salt://win/repo-ng/vscode/...

{% set PROGRAM_FILES = "%ProgramFiles%" %}
{% set VERSIONS = ['1.85.1' ,'1.58.0'] %}

vscode:
  {% for version in VERSIONS %}
  '{{version}}':
    full_name: 'Microsoft Visual Studio Code'
    installer: 'salt://blobs/vscode/VSCodeSetup-x64-{{ version }}.exe'
    uninstaller: '{{ PROGRAM_FILES }}\Microsoft VS Code\unins000.exe'
    install_flags: '/SP- /VERYSILENT /NORESTART /MERGETASKS="!RUNCODE,ADDCONTEXTMENUFILES,ADDCONTEXTMENUFOLDERS,ADDTOPATH"'
    uninstall_flags: '/VERYSILENT /NORESTART'
    msiexec: False
    locale: en_US
    reboot: False
  {% endfor %}
