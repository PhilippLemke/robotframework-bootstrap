# Client Role coding or execution
# Can be also set via cmd in deployment process
client-role: coding
#role: execution-client

install-mode: public
#install-mode: [public|cloud|local]


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
  python3_x64:
    # 150.0 is added to all python versions by default on win64 systems (outside salt context) so has to be also respected here
      version: 3.10.9150.0

#installed only on coding client
apps-coding:
  vscode:
    version: 1.87.2
    extension-source-dir: blobs\vscode\extensions
    #extensions:
    #  - d-biehl.robotcode
    #  - ms-python.python
  firefox:
    version: 107.0

  greenshot:
    version: 1.2.10.6

# Some static settings
python_home: C:\Program Files\Python310
pip_local_pkg_path: C:\RF-Bootstrap\pkgs\pip
vscode_bin: 'C:\Program Files\Microsoft VS Code\bin\code.cmd'