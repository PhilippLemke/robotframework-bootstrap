# Deploy Robotframework 


## Windows

1. Start Powershell as administrator

```powershell
Invoke-WebRequest -Uri https://winbootstrap.saltproject.io -OutFile C:\Temp\bootstrap-salt.ps1
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
C:\Temp\bootstrap-salt.ps1
Set-ExecutionPolicy -ExecutionPolicy Undefined -Scope CurrentUser

```

