# Install an additional current version of python to be independent
{% set python_home = 'C:\Program Files\Python39' %}
{% set web_driver_path = salt['pillar.get']('web_driver_path', 'C:\webdriver') %}
{% set browsers = salt['pillar.get']('selenium:browsers', []) %}
{% set pip_packages = salt['pillar.get']('pip-packages', {}) %}

# Todo: Upgrade pip first"c:\program files\python39\python.exe" -m pip install --upgrade pip

{% macro install_pip_package(package) -%}
install_{{ package }}:
  pip.installed:
    - name: {{ package }}
    - cwd: '{{ python_home }}\scripts'
    - bin_env: '{{ python_home }}\scripts\pip.exe'
    - upgrade: True
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

{% for browser in browsers %}
install-browser-{{browser}}:
  cmd.run:
    - name: >
        "{{ python_home }}\\python" -m webdrivermanager --linkpath {{ web_driver_path }} {{ browser }}
{% endfor %}

{% endmacro %}

{#
refresh-pkg-db:
  cmd.run:
    - name: salt-call --local pkg.refresh_db
#}

python3_x64:
  pkg.installed:
    - version: 3.9.4150.0
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


