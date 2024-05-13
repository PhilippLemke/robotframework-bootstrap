# Deploy Robot Framework 

## Windows

### Client with "full" internet access

1. Start Powershell as administrator

#### Boostrap Salt
```powershell
$saltversion=3006.7
New-Item -ItemType Directory -Force -Path C:\temp
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri https://winbootstrap.saltproject.io -OutFile C:\Temp\bootstrap-salt.ps1
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
C:\Temp\bootstrap-salt.ps1 -RunService false -Version $saltversion
```

#### Bootstrap Robot Framework
Prepare Installer
```powershell
Invoke-WebRequest -Uri https://github.com/PhilippLemke/robotframework-bootstrap/raw/master/bootstrap-robotframework.ps1 -OutFile C:\Temp\bootstrap-robotframework.ps1
C:\Temp\bootstrap-robotframework.ps1
cmd
```

Install Robot Framework and additional software 
```cmd
cd /d C:\RF-Bootstrap\salt-app\

salt-call --local --config-dir=C:\RF-Bootstrap\salt-data\conf saltutil.sync_all
salt-call --local --config-dir=C:\RF-Bootstrap\salt-data\conf state.apply deploy-rf-client
```


#### Bootstrap Robot Framework old fashion way
```powershell
Invoke-WebRequest -Uri https://github.com/PhilippLemke/robotframework-bootstrap/raw/master/bootstrap-robotframework -OutFile C:\Temp\bootstrap-robotframework.ps1
C:\Temp\bootstrap-robotframework.ps1
```

###  Build local installer for clients without internet access
This will use the current version of salt to build an local installer

Requirements: 
- Client with internet access




https://github.com/PhilippLemke/robotframework-bootstrap