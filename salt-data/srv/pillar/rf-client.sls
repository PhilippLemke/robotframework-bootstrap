# Client Role coding or execution
# Can be also set via cmd in deployment process
client-role: coding
#role: execution-client

# Robot Framework Bootstrap-Config
pip-packages:
  base:
    - wheel
    - requests

  robotframework:
    - PyScreeze==0.1.29
    - PyAutoGUI==0.9.54
    - robotframework==6.0
    - robotframework-browser
    - robotframework-imagehorizonlibrary
    - robotframework-autoitlibrary
    - robotframework-crypto

  robotmk:
    - mergedeep
    - dateutils
    - pyyaml

#installed on coding and execution client
apps-common:
  aws_cli:
    version: 2.4.0

  python3_x64:
    # 150.0 is added to all python versions by default on win64 systems (outside salt context) so has to be also respected here
    version: 3.10.9150.0

  git:
    version: 2.45.0

  nodejs:
    version: 20.11.1

#installed only on coding client
apps-coding:
  vscode:
    version: 1.89.1
    # in public mode inst
  firefox:
    version: 107.0

  greenshot:
    version: 1.2.10.6

# Requires a visual code installation
# You can specify them withhout a specific version, but currently only for public install supported
# Recommendation: Specify the extensions every time with @version
vscode-extensions:
  - d-biehl.robotcode@0.82.3
  - ms-python.python@2024.6.0
  - korekontrol.saltstack@0.0.9
 

# Some static settings
python_home: C:\Program Files\Python310
pip_local_pkg_path: C:\RF-Bootstrap\pkgs\pip
inst_local_pkg_path: C:\RF-Bootstrap\pkgs\blobs
vscode_bin: 'C:\Program Files\Microsoft VS Code\bin\code.cmd'
vscode_extension_source_dir: C:\RF-Bootstrap\pkgs\blobs\vscode\extensions

{# TODO: Maybe we can use this in the future to use relative paths
{#
{% set salt_file_roots = salt['config.get']('file_roots','') %}
{% set salt_base = salt_file_roots["base"][1] + '\\'  %}
inst_local_pkg_path:  {{ salt_base }}
#}