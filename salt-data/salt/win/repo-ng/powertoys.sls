{% set EXE_VERSIONS = [ '0.76.2' ] %}

powertoys:
  {% for VER in EXE_VERSIONS %}
  '{{ VER }}':
    full_name: 'PowerToys (Preview) x64'
    installer: 'salt://blobs/powertoys/PowerToysSetup-{{ VER }}-x64.exe'
    install_flags: '/install /quiet'
    #uninstaller: '%ProgramFiles%/Greenshot/unins000.exe'
    uninstall_flags: '/uninstall /quiet'
    msiexec: False
    locale: en_US
    reboot: False
  {% endfor %}
