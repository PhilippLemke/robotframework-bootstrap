# Install an additional current version of python to be independent from salt runtime env
{% set python_home = 'C:\Program Files\Python39' %}
{% set web_driver_path = salt['pillar.get']('web_driver_path', 'C:\webdriver') %}
{% set browsers = salt['pillar.get']('selenium:browsers', []) %}
{% set pip_packages = salt['pillar.get']('pip-packages', {}) %}
{% set local_webdriver = salt.cp.list_master_dirs(prefix='blobs/webdriver') | count %}

# Todo: Upgrade pip first"c:\program files\python39\python.exe" -m pip install --upgrade pip

{% macro install_pip_package(package) -%}
install_{{ package }}:
  pip.installed:
    - name: {{ package }}
    - cwd: '{{ python_home }}\scripts'
    - bin_env: '{{ python_home }}\scripts\pip.exe'
    - no_index: True
    - find_links: C:\RFW_Bootstrap\pip
{% endmacro %}

{% macro provide_selenium_addons() %}
{{ web_driver_path }}:
  file.directory

{% if not web_driver_path in salt['win_path.get_path']() %}
ensure-web-drivers-in-path:
  module.run:
    - name: win_path.add
    - path: {{ web_driver_path}}
    - index: -1
{% endif %}

{% if local_webdriver %}
ensure-webdriver-present:
  file.recurse:
    - name: {{ web_driver_path }}
    - source: salt://blobs/webdriver
{% endif %}

{% for browser, data in browsers.items() %}
{% if data["install"] %}
install-browser-{{browser}}:
  pkg.installed:
    - name: {{ browser }}
    - version: {{ data["version"] }}
{% endif %}

# if no local drivers found in salt file root, try to install current via webdriver manager
{% if not local_webdriver %}
install-webdriver-for-{{browser}}:
  cmd.run:
    - name: >
        "{{ python_home }}\\python" -m webdrivermanager --linkpath {{ web_driver_path }} {{ browser }}
{% endif %}
{% endfor %}

{% endmacro %}

{#
refresh-pkg-db:
  cmd.run:
    - name: salt-call --local pkg.refresh_db
#}

set_visual_effects_for_best_performance:
  reg.present:
    - name: HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects
    - vname: VisualFXSetting
    - vdata: 2
    - vtype: REG_DWORD

#
#powertoys:
#  pkg.installed:
#    - version: 0.76.2
#    - refresh: True

python3_x64:
  pkg.installed:
    - version: 3.9.8150.0
    - refresh: True

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


{% if pip_packages|length > 0 %}
# start for loop sections in -> pip-packages:
{% for section, packages in pip_packages.items() %}

# start for loop package in packages:
{% for package in packages %}

{{ install_pip_package(package) }}

{% if package == "robotframework-imagehorizonlibrary" %}
{{ install_pip_package('Pillow') }}
{{ install_pip_package('opencv-python') }}

{% elif package == "robotframework-seleniumlibrary" %}
{{ install_pip_package('selenium') }}
{{ install_pip_package('webdrivermanager') }}
{{ provide_selenium_addons() }}
{% endif %}

# end for loop package in packages:
{% endfor %}

# end for loop sections in -> pip-packages:
{% endfor %}
{% endif %}

# start if client-role
{% if salt['pillar.get']('client-role', "coding") == "coding" %}
# install additional apps if coding client 
{% for app, specs in salt['pillar.get']('additional-apps', {}).items() %}
app-inst-{{app}}:
  pkg.installed:
    - name: {{ app }}
    - version: {{ specs["version"] }}
{% endfor %}

# install vscode extensions
{% set salt_base = salt['config.get']('file_roots','') %}
# Todo write a salt execution and state module to manage vscode extensions 
{% set vscode_extensions_dir = salt['pillar.get']('additional-apps:vscode:extension-source-dir', None)  %}
{% set vscode_extensions = salt['pillar.get']('additional-apps:vscode:extensions', []) %}
{% set vscode_bin = "C:\\Program Files\\Microsoft VS Code\\bin\\code.cmd" %} 

# First try to install locally provided extensions. The state iterates over extension-source-dir and installs all files with the suffix vsix
{% if vscode_extensions_dir %}
{% set vscode_extensions_dir = salt_base["base"][0] + '\\' + vscode_extensions_dir  %}
{% set vscode_local_extensions = salt['file.readdir'](vscode_extensions_dir)  %}
{% for ext in vscode_local_extensions -%}
{% if ext.endswith('vsix')%}
local-install-vscode-ext-{{ ext }}:
  cmd.run:
    - name: >
        "{{ vscode_bin }}" --install-extension {{ vscode_extensions_dir }}\{{ ext }}
{% endif %}
{% endfor %}
{% endif %}

# Try to install in pillar defined  extension via internet
{% for ext in vscode_extensions -%}
install-vscode-ext-{{ ext }}:
  cmd.run:
    - name: >
        "{{ vscode_bin }}" --install-extension {{ ext }}
{% endfor %}
# end if client-role
{% endif %}