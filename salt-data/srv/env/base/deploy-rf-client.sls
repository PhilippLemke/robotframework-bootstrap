{% from "macros/pip.sls" import install_pip_package, install_pip_package_local with context %}
{% from "macros/install_base.sls" import app_install, vscode_local_extension_install with context %}
{% from "macros/aws.sls" import download_aws_package with context %}

include:
  - aws.create-cli-config
  - regedit.set_visual_effects

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
{% set s3_bucket = salt['config.get']('s3.bucket', 'specify s3_bucket in pillars') %}
{% set inst_local_pkg_path = salt['pillar.get']('inst_local_pkg_path', 'set inst-local-pkg-path in pillar') %}

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


# Todo: Upgrade pip first"c:\program files\python39\python.exe" -m pip install --upgrade pip
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

{% set vscode_extensions = salt['pillar.get']('vscode-extensions', []) %}
{% set vscode_extension_source_dir = salt['pillar.get']('vscode_extension_source_dir', "Please define vscode_extenstion_source_dir  in pillar")  %}

{% if install_mode == 'local' %}
{{ vscode_local_extension_install(vscode_extensions, vscode_extension_source_dir) }}

# Try to install in pillar defined extension via internet
{% elif install_mode == 'base' %}
{% for ext in vscode_extensions -%}
install-vscode-ext-{{ ext }}:
  vscode.extension_installed:
    - name: {{ ext }}
# end for loop ext in vscode_extensions
{% endfor %}

{% elif install_mode == 'cloud' %}
# Example inst_local_pkg_path: C:\RF-Bootstrap\pkgs\blobs
{{ download_aws_package(s3_bucket, 'blobs/vscode/extensions', vscode_extension_source_dir) }}
{{ vscode_local_extension_install(vscode_extensions, vscode_extension_source_dir) }}

# end if install_mode == base, cloud or local
{% endif %}
# end if client-role
{% endif %}

