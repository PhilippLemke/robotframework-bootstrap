# original source: https://github.com/saltstack/salt-winrepo-ng/blob/master/vscode.sls

{% set PROGRAM_FILES = "%ProgramFiles%" %}

{% set VERSIONS = (
        ('1.89.1', 'dc96b837cf6bb4af9cd736aa3af08cf8279f7685'),
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
