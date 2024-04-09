# Install an additional current version of python to be independent from salt runtime env
#{% set python_home = 'C:\Program Files\Python39' %}
{% set install_mode = salt['pillar.get']('install-mode', 'online') %}
{% set client_role = salt['pillar.get']('client-role', 'coding') %}

{% set python_home = salt['pillar.get']('python_home', 'set python_home in pillar') %}
{% set additional_apps = salt['pillar.get']('additional-apps', {}) %}
{% set vscode_bin = salt['pillar.get']('vscode_bin', 'set vscode_bin in pillar') %}
{% set vscode_extensions = salt['pillar.get']('additional-apps:vscode:extensions', []) %}
{% set vscode_extensions_dir = salt['pillar.get']('additional-apps:vscode:extension-source-dir', None) %}
{% set pip_packages = salt['pillar.get']('pip-packages', {}) %}
{% set pip_offline_pkg_path = salt['pillar.get']('pip-offline-pkg-path', 'set pip-offline-pkg-path in pillar') %}

# Todo: Upgrade pip first"c:\program files\python39\python.exe" -m pip install --upgrade pip

{% macro install_pip_package(package) -%}
install_{{ package }}:
  pip.installed:
    - name: {{ package }}
    - cwd: '{{ python_home }}\scripts'
    - bin_env: '{{ python_home }}\scripts\pip.exe'
    - upgrade: True
{% endmacro %}


{% macro install_pip_package_offline(package, pip_offline_pkg_path) -%}
install_{{ package }}:
  pip.installed:
    - name: {{ package }}
    - cwd: '{{ python_home }}\scripts'
    - bin_env: '{{ python_home }}\scripts\pip.exe'
    - no_index: True
    # use variable instead of hardcoded path to avoid issues with salt runtime env
    - find_links: {{ pip_offline_pkg_path }}
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

# start for loop pip package in packages:
{% for package in packages %}
{% if install_mode == 'offline' %}
{{ install_pip_package_offline(package, pip_offline_pkg_path) }}
{% else %}
{{ install_pip_package(package) }}
# end if install-mode == 'offline'
{% endif %}
{% endfor %}
# end for loop package in packages:
{% endfor %}
# end for loop sections in -> pip-packages:
{% endif %}

# start if client-role
{% if salt['pillar.get']('client-role', "coding") == "coding" %}
# install additional apps if coding client 
{% for app, specs in additional_apps.items() %}
app-inst-{{app}}:
  pkg.installed:
    - name: {{ app }}
    - version: {{ specs["version"] }}
{% endfor %}

# install vscode extensions
{% set salt_base = salt['config.get']('file_roots','') %}
# Todo write a salt execution and state module to manage vscode extensions 
{#
{% set vscode_extensions_dir = salt['pillar.get']('additional-apps:vscode:extension-source-dir', None)  %}
{% set vscode_extensions = salt['pillar.get']('additional-apps:vscode:extensions', []) %}
#}

# First try to install locally provided extensions. The state iterates over extension-source-dir and installs all files with the suffix vsix
{% if install_mode == 'offline' %}
{% if vscode_extensions_dir %}
{% set vscode_extensions_dir = salt_base["base"][1] + '\\' + vscode_extensions_dir  %}
{% set vscode_local_extensions = salt['file.readdir'](vscode_extensions_dir)  %}
{% for ext in vscode_local_extensions -%}
{% if ext.endswith('vsix')%}
local-install-vscode-ext-{{ ext }}:
  cmd.run:
    - name: >
        "{{ vscode_bin }}" --install-extension {{ vscode_extensions_dir }}\{{ ext }}
# endif ext.endswith('vsix')
{% endif %}
{% endfor %}
# end if vscode_extensions_dir
{% endif %}
# end if install_mode == 'offline'
{% endif %}

# Try to install in pillar defined extension via internet
{% if install_mode == 'online' %}
{% for ext in vscode_extensions -%}
install-vscode-ext-{{ ext }}:
  cmd.run:
    - name: >
        "{{ vscode_bin }}" --install-extension {{ ext }}
# end for loop ext in vscode_extensions
{% endfor %}
# end if install_mode == 'online'
{% endif %}
# end if client-role
{% endif %}