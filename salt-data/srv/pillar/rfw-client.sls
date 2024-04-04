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
    - robotframework-crypto:3123

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