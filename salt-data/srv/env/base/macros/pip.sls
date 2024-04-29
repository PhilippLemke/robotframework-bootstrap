{% macro install_pip_package(package, python_home) -%}
install_{{ package }}:
  pip.installed:
    - name: {{ package }}
    - cwd: '{{ python_home }}\scripts'
    - bin_env: '{{ python_home }}\scripts\pip.exe'
    - upgrade: True
{% endmacro %}


{% macro install_pip_package_local(package, pip_local_pkg_path, python_home) -%}
install_{{ package }}:
  pip.installed:
    - name: {{ package }}
    - cwd: '{{ python_home }}\scripts'
    - bin_env: '{{ python_home }}\scripts\pip.exe'
    - no_index: True
    # use variable instead of hardcoded path to avoid issues with salt runtime env
    - find_links: {{ pip_local_pkg_path }}
{% endmacro %}


{% macro download_pip_package(package, pip_local_pkg_path) -%}
download_{{ package }}:
  cmd.run:
    - name: pip download -d {{ pip_local_pkg_path }} {{ package }}
{% endmacro %}