{% from "macros/pip.sls" import download_pip_package with context %}

{% set install_mode = salt['config.get']('saltenv', 'base') %}
{% set pip_packages = salt['pillar.get']('pip-packages', {}) %}
{% set pip_local_pkg_path = salt['pillar.get']('pip_local_pkg_path', 'set pip-local-pkg-path in pillar') %}


{% if pip_packages|length > 0 %}
{% if install_mode == 'local' %}
env-local-download:
  test.fail_without_changes:
    - name: Download is only available in the Environments public and cloud
{% elif install_mode == 'base' %}
# start for loop sections in -> pip-packages:
{% for section, packages in pip_packages.items() %}
# start for loop pip package in packages:
{% for package in packages %}
{{ download_pip_package(package, pip_local_pkg_path) }}
{% endfor %}
# end for loop package in packages:
{% endfor %}
{% elif install_mode == 'cloud' %}
env-local-download:
  test.fail_without_changes:
    - name: Cloud download method is not yet implemented!
# end elif install-mode 
{% endif %}
# end for loop sections in -> pip-packages:
{% endif %}