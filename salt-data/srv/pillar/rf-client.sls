# Client Role coding or execution
# Can be also set via cmd in deployment process
client-role: coding
#role: execution-client

install-mode: online
#install-mode: [online|cloud|offline]


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


additional-apps:
  vscode:
    install: True
    version: 1.85.1
    extension-source-dir: blobs\vscode\extensions
    #extensions:
    #  - d-biehl.robotcode
    #  - ms-python.python

  greenshot:
    install: True
    version: 1.2.10.6

# Some static settings
python_home: C:\Program Files\Python39
pip_offline_pkg_path: C:\RF-Bootstrap\pkgs\pip
vscode_bin: 'C:\Program Files\Microsoft VS Code\bin\code.cmd'