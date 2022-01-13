# Deploy Robotframework 


## Windows

1. Start Powershell as administrator

### Boostrap Salt
```powershell
New-Item -ItemType Directory -Force -Path C:\temp
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri https://winbootstrap.saltproject.io -OutFile C:\Temp\bootstrap-salt.ps1
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
C:\Temp\bootstrap-salt.ps1
```

### Bootstrap Robotframework
```powershell
Invoke-WebRequest -Uri https://github.com/PhilippLemke/robotframework-bootstrap/raw/master/bootstrap-robotframework -OutFile C:\Temp\bootstrap-robotframework.ps1
C:\Temp\bootstrap-robotframework.ps1
```

