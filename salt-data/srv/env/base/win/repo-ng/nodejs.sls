{% set EXE_VERSIONS = [ '20.11.1' ] %}

nodejs:
  {% for VER in EXE_VERSIONS %}
  '{{ VER }}':
    full_name: 'Node.js'
    installer: 'https://nodejs.org/dist/v{{ VER }}/node-v{{ VER }}-x64.msi'
    #installer: 'salt://blobs/nodejs/node-v{{ VER }}-x64.msi'
    install_flags: '/qn /norestart'
    #uninstaller: '%ProgramFiles%/Greenshot/unins000.exe'
    uninstall_flags: /qn /norestart
    msiexec: True
    locale: en_US
    reboot: False
  {% endfor %}

  #msiexec /i  node-v20.11.1-x64.msi /qn /norestart

