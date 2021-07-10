# Robot Framework Bootstrap-Config

pip-packages:
  robotframework:
    - robotframework
    - robotframework-seleniumlibrary
    - robotframework-browser
    - robotframework-imagehorizonlibrary

  robotmk:
    - mergedeep
    - dateutils
    - pyyaml

# only honored if robotframework-seleniumlibrary is in pip-packages 
selenium:
  web_driver_path: C:\webdriver
  browsers:
    - firefox
    - chrome
  install_browsers: False

vscode:
  install_vscode: True
  extensions:
    - robocorp.robotframework-lsp
    - ms-python.python
