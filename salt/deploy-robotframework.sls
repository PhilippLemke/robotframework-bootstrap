# Install an additional current version of python to be independent
{% set python_home = 'C:\Program Files\Python39' %}
{% set web_driver_path = 'c:\\webdriver' %}
{% set browsers = ['chrome', 'firefox' ]%}

{% macro install_pip_package(package) -%}
install_{{ package }}:
  pip.installed:
    - name: {{ package }}
    - cwd: '{{ python_home }}\scripts'
    - bin_env: '{{ python_home }}\scripts\pip.exe'
    - upgrade: True
{% endmacro %}

refresh-pkg-db:
  cmd.run:
    - name: salt-call --local pkg.refresh_db

python3_x64:
  pkg.installed:
    - version: 3.9.4150.0


{% if not python_home in salt['win_path.get_path']() %}
ensure-python-in-path:
  module.run:
    - name: win_path.add
    - path: {{ python_home }}
    - index: -1
{% endif %}

{% if not python_home + '\scripts' in salt['win_path.get_path']() %}
ensure-python-scripts-in-path:
  module.run:
    - name: win_path.add
    - path: {{ python_home }}\scripts
    - index: -1
{% endif %}


{% set pip_packages = ['dateutils', 'mergedeep' , 'robotframework', 'selenium', 'pyyaml', 'robotframework-imagehorizonlibrary' ] %}
  
{% for package in pip_packages %}
{{ install_pip_package(package) }}
{% endfor %}

{#
{% if 'robotframework-imagehorizonlibrary' in pip_packages %}
{% set imagehorizon_addon_packages = ['pyautogui' ]%}
{% for package in imagehorizon_addon_packages %}
install_{{ package }}:
  pip.installed:
    - name: {{ package }}
    - cwd: 'C:\salt\bin\scripts'
    - bin_env: 'C:\salt\bin\scripts\pip.exe'
    - upgrade: True  
{% endfor %}
{% endif %}

{% if 'selenium' in pip_packages %}
{% set selenium_addon_packages = ['robotframework-seleniumlibrary', 'webdrivermanager' ]%}
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

#}
