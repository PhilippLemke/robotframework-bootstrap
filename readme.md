# Deploy Robotframework 


## Windows

1. Start Powershell as administrator

### Boostrap Salt
```powershell
Invoke-WebRequest -Uri https://winbootstrap.saltproject.io -OutFile C:\Temp\bootstrap-salt.ps1
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
C:\Temp\bootstrap-salt.ps1
```

### Bootstrap Robotframwork
```powershell
Invoke-WebRequest -Uri https://github.com/PhilippLemke/robotframework-bootstrap/raw/master/bootstrap-robotframwork -OutFile C:\Temp\bootstrap-robotframwork.ps1
C:\Temp\bootstrap-robotframwork.ps1
```

