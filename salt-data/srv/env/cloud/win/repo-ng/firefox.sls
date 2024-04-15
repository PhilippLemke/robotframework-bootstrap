# Firefox installs are available in many languages other than en-US
# See https://releases.mozilla.org/pub/firefox/releases/latest/README.txt
# for a list of possible installer language codes.
# minion pillar, grains or config file. See
# https://docs.saltstack.com/en/latest/ref/modules/all/salt.modules.config.html#salt.modules.config.get

{# {%- set lang = salt['config.get']('firefox:pkg:lang', 'en-US') %} #}
{% set lang = 'en-US' %}

firefox:
  {% for version in ['124.0.2', '107.0','98.0'] %}
  '{{ version }}':
    full_name: 'Mozilla Firefox (x64 {{ lang }})'
    installer: https://download-installer.cdn.mozilla.net/pub/firefox/releases/{{ version }}/win64/{{ lang }}/Firefox%20Setup%20{{ version }}.exe
    #          https://download-installer.cdn.mozilla.net/pub/firefox/releases/124.0.2/win64/en-US/
    # installer: 'salt://blobs/firefox/{{ lang }}/Firefox Setup {{ version }}.exe'
    install_flags: '/S'
    uninstaller: '%ProgramFiles%\Mozilla Firefox\uninstall\helper.exe'
    uninstall_flags: '/S'
    msiexec: False
    locale: en_US
    reboot: False
  {% endfor %}

