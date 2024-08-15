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

#### Bootstrap Robot Framework via Proxy ()
```
# Define the version of Salt and proxy settings
$saltversion = "3006.7"

# Set this variable to your proxy URL if needed, e.g., "http://proxyserver:port"
$proxy = "http://myproxy.local:port"  

# Create a directory to store the bootstrap script
New-Item -ItemType Directory -Force -Path C:\temp

# Set the security protocol to TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Check if a proxy is needed and configure the web request accordingly
if ($proxy -ne $null) {
    $proxyUri = New-Object System.Uri($proxy)
    # Download the bootstrap script using the specified proxy
    Invoke-WebRequest -Uri "https://winbootstrap.saltproject.io" -OutFile C:\Temp\bootstrap-salt.ps1 -Proxy $proxyUri -ProxyUseDefaultCredentials
} else {
    # Download the bootstrap script without a proxy
    Invoke-WebRequest -Uri "https://winbootstrap.saltproject.io" -OutFile C:\Temp\bootstrap-salt.ps1
}

# Set the execution policy to unrestricted for the current user
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser

# Run the bootstrap script with specified options
C:\Temp\bootstrap-salt.ps1 -RunService $false -Version $saltversion
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