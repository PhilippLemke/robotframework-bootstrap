{% set EXE_VERSIONS = [ '3.10.9', '3.9.8', '3.9.4' ] %}

python3_x64:
  {% for VER in EXE_VERSIONS %}
      {% set install_source = 'https://www.python.org/ftp/python/' + {{ VER }} + '/python'  %}
  '{{ VER }}150.0':
    full_name: 'Python {{ VER }} Core Interpreter (64-bit)'
    installer: '{{ install_source }}/python-{{ VER }}-amd64.exe'
    install_flags: '/quiet InstallAllUsers=1'
    uninstaller: '{{ install_source }}/python-{{ VER }}-amd64.exe'
    uninstall_flags: '/quiet /uninstall'
    msiexec: False
    locale: en_US
    reboot: False
  {% endfor %}
