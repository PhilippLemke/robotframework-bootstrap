{% set web_driver_path = 'c:\\webdriver' %}
{% set browsers = ['chrome', 'firefox' ]%}

{% if not 'c:\\salt\\bin' in salt['win_path.get_path']() %}
ensure-python-in-path:
  module.run:
    - name: win_path.add
    - path: 'c:\salt\bin'
    - index: -1
{% endif %}
  
{% set pip_packages = ['dateutils', 'mergedeep' , 'robotframework', 'selenium', 'pyyaml' ] %}
  
{% for package in pip_packages %}
install_{{ package }}:
  pip.installed:
    - name: {{ package }}
    - cwd: 'C:\salt\bin\scripts'
    - bin_env: 'C:\salt\bin\scripts\pip.exe'
    - upgrade: True
  
{% endfor %}


{% if 'selenium' in pip_packages %}
{%  set selenium_addon_packages = ['robotframework-seleniumlibrary', 'webdrivermanager' ]%}
{% for package in selenium_addon_packages %}
install_{{ package }}:
  pip.installed:
    - name: {{ package }}
    - cwd: 'C:\salt\bin\scripts'
    - bin_env: 'C:\salt\bin\scripts\pip.exe'
    - upgrade: True  
{% endfor %}

{{ web_driver_path }}:
  file.directory

{% if not web_driver_path in salt['win_path.get_path']() %}
ensure-web-drivers-in-path:
  module.run:
    - name: win_path.add
    - path: {{ web_driver_path}}
    - index: -1
{% endif %}

{% for browser in browsers %}
install-browser-{{browser}}:
  cmd.run:
    - name: c:\salt\bin\python -m webdrivermanager --linkpath {{ web_driver_path }} {{ browser}}
{% endfor %}

{% endif %}


