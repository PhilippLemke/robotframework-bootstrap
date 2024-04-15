# original source: https://github.com/saltstack/salt-winrepo-ng/blob/master/vscode.sls
# due to winrepo installer limitations you need to manually download x86 + x64 System installer from
# https://code.visualstudio.com/Download
# and put it on the winrepo on master to install it the 'salt://win/repo-ng/vscode/...

{% set PROGRAM_FILES = "%ProgramFiles%" %}
{% set VERSIONS = ['1.87.2', '1.85.1' ,'1.58.0'] %}

{% set VERSIONS = (
        ('1.87.2', '863d2581ecda6849923a2118d93a088b0745d9d6'),
        ('1.88.0', '5c3e652f63e798a5ac2f31ffd0d863669328dc4c'),
        ('1.73.1', '6261075646f055b99068d3688932416f2346dd3b'),
        ('1.58.0', '2d23c42a936db1c7b3b06f918cde29561cc47cd6'),
)
%}
vscode:
  {% for version, guid in VERSIONS %}
  '{{version}}':
    full_name: 'Microsoft Visual Studio Code'
    #installer: 'salt://blobs/vscode/VSCodeSetup-x64-{{ version }}.exe'
    #installer: 'https://az764295.vo.msecnd.net/stable/{{ guid }}/VSCodeSetup-x64-{{version}}.exe'
    installer: 'https://vscode.download.prss.microsoft.com/dbazure/download/stable/{{ guid }}/VSCodeSetup-x64-{{ version }}.exe'

    uninstaller: '{{ PROGRAM_FILES }}\Microsoft VS Code\unins000.exe'
    install_flags: '/SP- /VERYSILENT /NORESTART /MERGETASKS="!RUNCODE,ADDCONTEXTMENUFILES,ADDCONTEXTMENUFOLDERS,ADDTOPATH"'
    uninstall_flags: '/VERYSILENT /NORESTART'
    msiexec: False
    locale: en_US
    reboot: False
  {% endfor %}
