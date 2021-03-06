# Robot Framework Bootstrap-Config

pip-packages:
  base:
    - wheel

  robotframework:
    - robotframework
    - robotframework-seleniumlibrary
    - robotframework-browser
    - robotframework-imagehorizonlibrary
    - robotframework-autoitlibrary
    - robotframework-crypto

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
