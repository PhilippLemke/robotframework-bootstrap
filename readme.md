# Deploy Robotframework 


## Windows

1. Start Powershell as administrator

```powershell
#Boostrap Salt
Invoke-WebRequest -Uri https://winbootstrap.saltproject.io -OutFile C:\Temp\bootstrap-salt.ps1
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
C:\Temp\bootstrap-salt.ps1

#Bootstrap Robotframwork
Invoke-WebRequest -Uri https://github.com/PhilippLemke/robotframework-bootstrap/bootstrap-robotframwork.ps1 -OutFile C:\Temp\bootstrap-robotframwork.ps1
C:\Temp\bootstrap-robotframwork.ps1
```

