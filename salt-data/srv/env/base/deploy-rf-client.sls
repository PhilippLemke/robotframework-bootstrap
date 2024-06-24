{% from "macros/pip.sls" import install_pip_package, install_pip_package_local with context %}
{% from "macros/install_base.sls" import app_install with context %}

include:
  - aws.create-cli-config

#{% set install_mode = salt['pillar.get']('install-mode', 'public') %}
# base = public
{% set install_mode = salt['config.get']('saltenv', 'base') %}

{% set client_role = salt['pillar.get']('client-role', 'coding') %}

{% set python_home = salt['pillar.get']('python_home', 'set python_home in pillar') %}
{% set apps_common = salt['pillar.get']('apps-common', {}) %}
{% set apps_coding = salt['pillar.get']('apps-coding', {}) %}
{% set vscode_bin = salt['pillar.get']('vscode_bin', 'set vscode_bin in pillar') %}
{% set vscode_extensions = salt['pillar.get']('additional-apps:vscode:extensions', []) %}
{% set vscode_extension_source_dir = salt['pillar.get']('vscode_extension_source_dir', 'set vscode_extension_source_dir in pillar') %}
{% set pip_packages = salt['pillar.get']('pip-packages', {}) %}
{% set pip_local_pkg_path = salt['pillar.get']('pip_local_pkg_path', 'set pip-local-pkg-path in pillar') %}

# Todo: Upgrade pip first"c:\program files\python39\python.exe" -m pip install --upgrade pip

# Disable visual effects for best performance to ensure smooth edges for fonts and scroll list boxes are disabled. Important for RF ImageHorizonLibrary!
set_visual_effects_for_best_performance:
  reg.present:
    - name: HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects
    - vname: VisualFXSetting
    - vdata: 2
    - vtype: REG_DWORD

# install common apps for all environments
{% for app, specs in apps_common.items() %}
{{ app_install(app, specs["version"]) }}
{% endfor %}

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
{% if install_mode == 'local' %}
{{ install_pip_package_local(package, pip_local_pkg_path, python_home) }}
{% else %}
{{ install_pip_package(package, python_home) }}
# end if install-mode == 'local'
{% endif %}
{% endfor %}
# end for loop package in packages:
{% endfor %}
# end for loop sections in -> pip-packages:
{% endif %}


# start if client-role
{% if client_role == "coding" %}

# install additional apps if coding client 
{% for app, specs in apps_coding.items() %}
{{ app_install(app, specs["version"]) }}
{% endfor %}

# install vscode extensions defined in pillars
#vscode-extensions:
#  - d-biehl.robotcode@0.79.0
#  - ms-python.python@2024.5.11172159

{% set vscode_extensions = salt['pillar.get']('vscode-extensions', []) %}
{% set vscode_extension_source_dir = salt['pillar.get']('vscode_extension_source_dir', "Please define vscode_extenstion_source_dir  in pillar")  %}

# First try to install locally provided extensions. The state iterates over extension-source-dir and installs all files with the suffix vsix
{% if install_mode == 'local' %}
{#
{% set vscode_local_extensions = salt['file.readdir'](vscode_extension_source_dir)  %}
#}
{% for ext in vscode_extensions -%}
{% set parts = ext.split('@') %}
{% set ext = parts[0] %}
{% set version = parts[1] if parts|length > 1 else None %}
{% if not version %}
version-for-vscode-ext-{{ ext }}:
  test.configurable_test_state:
    - name: undefined
    - changes: False
    - result: False
    - comment: Please define version in pillar, that is necessary for cloud or local install
# end if not version
{% endif %}
local-install-vscode-ext-{{ ext }}:
  vscode.extension_installed:
    - name: {{ ext }}
    - install_path: {{ vscode_extension_source_dir }}
    - version: {{ version }}
{% endfor %}
# end if install_mode == 'local'
{% endif %}

# Try to install in pillar defined extension via internet
{% if install_mode == 'base' %}
{% for ext in vscode_extensions -%}
install-vscode-ext-{{ ext }}:
  vscode.extension_installed:
    - name: {{ ext }}

# end for loop ext in vscode_extensions
{% endfor %}
# end if install_mode == 'public'
{% endif %}
# end if client-role
{% endif %}

