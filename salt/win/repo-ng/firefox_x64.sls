# Firefox installs are available in many languages other than en-US
# See https://releases.mozilla.org/pub/firefox/releases/latest/README.txt
# for a list of possible installer language codes.
# To install Firefox in a particular language on a minion, set the value of
# `firefox:pkg:lang` to a language code in the master config file,
# minion pillar, grains or config file. See
# https://docs.saltstack.com/en/latest/ref/modules/all/salt.modules.config.html#salt.modules.config.get

{# {%- set lang = salt['config.get']('firefox:pkg:lang', 'en-US') %} #}
{% set lang = 'en-US' %}

firefox_x64:
  {% for version in ['95.0.2', '89.0', '88.0.1', '88.0', '87.0', '86.0.1', '86.0', '85.0.2', '85.0.1', '85.0', '84.0.2', '84.0.1', '84.0', '83.0'] %}
  '{{ version }}':
    full_name: 'Mozilla Firefox {{ version }} (x64 {{ lang }})'
    installer: 'https://download-installer.cdn.mozilla.net/pub/firefox/releases/{{ version }}/win64/{{ lang }}/Firefox%20Setup%20{{ version }}.exe'
    install_flags: '/S'
    uninstaller: '%ProgramFiles%\Mozilla Firefox\uninstall\helper.exe'
    uninstall_flags: '/S'
    msiexec: False
    locale: en_US
    reboot: False
  {% endfor %}
