{% if not "c:\\salt\\bin" in salt['win_path.get_path']() %}
ensure-python-in-path:
  module.run:
    - name: win_path.add
    - path: 'c:\salt\bin'
    - index: -1
{% endif %}
  
{% set pip_packages = ['dateutils', 'mergedeep' , 'robotframework', 'webdrivermanager', 'selenium', 'robotframework-seleniumlibrary', 'pyyaml' ] %}
  
{% for package in pip_packages %}
install_{{ package }}:
  pip.installed:
    - name: {{ package }}
    - cwd: 'C:\salt\bin\scripts'
    - bin_env: 'C:\salt\bin\scripts\pip.exe'
    - upgrade: True
  
{% endfor %}

