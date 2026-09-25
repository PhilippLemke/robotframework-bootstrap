param (
    [string]$Proxy,
    [switch]$SkipInstall
)

$saltVersion = "3006.19"
$repo = "PhilippLemke/robotframework-bootstrap"
$saltFolderPath = "C:\Program Files\Salt Project\Salt"
$tempFolderPath = "C:\Temp"

# Set the security protocol to TLS 1.2
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Create the temporary directory if it doesn't exist
New-Item -ItemType Directory -Force -Path $tempFolderPath | Out-Null

function Invoke-Download {
    param (
        [string]$Uri,
        [string]$OutFile
    )

    if ($Proxy) {
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -Proxy $Proxy -ProxyUseDefaultCredentials
    } else {
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile
    }
}

# Look up the most recently created git tag for $repo via the GitHub API (no git CLI required
# on the target machine at this point). Falls back to master if the lookup fails or no tags
# exist yet.
function Get-LatestTag {
    param (
        [string]$repo
    )

    $uri = "https://api.github.com/repos/$repo/tags"

    try {
        if ($Proxy) {
            return (Invoke-RestMethod -Uri $uri -Proxy $Proxy -ProxyUseDefaultCredentials -Headers @{ "User-Agent" = "robotframework-bootstrap" })[0].name
        } else {
            return (Invoke-RestMethod -Uri $uri -Headers @{ "User-Agent" = "robotframework-bootstrap" })[0].name
        }
    } catch {
        Write-Host "Could not resolve the latest release tag ($($_.Exception.Message)). Falling back to master." -ForegroundColor Yellow
        return $null
    }
}

$latestTag = Get-LatestTag -repo $repo
if ($latestTag) {
    Write-Host "Using latest release: $latestTag"
    $ref = $latestTag
} else {
    $ref = "master"
}

# Define the bootstrap file paths
$bootstrapRobotFrameworkPath = Join-Path $tempFolderPath "bootstrap-robotframework.ps1"
$bootstrapSaltPath = Join-Path $tempFolderPath "bootstrap-salt.ps1"

# Download the bootstrap scripts from the resolved release, not a possibly-stale local copy
Invoke-Download -Uri "https://raw.githubusercontent.com/$repo/$ref/bootstrap-robotframework.ps1" -OutFile $bootstrapRobotFrameworkPath
Invoke-Download -Uri "https://raw.githubusercontent.com/$repo/$ref/bootstrap-salt.ps1" -OutFile $bootstrapSaltPath

# Run the Salt bootstrap script if the Salt folder does not exist
if (-not (Test-Path -Path $saltFolderPath)) {
    Write-Host "Salt installation not detected. Running bootstrap-salt.ps1..."
    if ($Proxy) {
        & $bootstrapSaltPath -RunService false -Version $saltVersion -p $Proxy -IgnoreSSL
    } else {
        & $bootstrapSaltPath -RunService false -Version $saltVersion
    }
} else {
    Write-Host "Salt installation detected at $saltFolderPath. Skipping Salt installation steps."
}

Write-Host "Running bootstrap-robotframework.ps1 ($ref)..."
if ($Proxy) {
    & $bootstrapRobotFrameworkPath -Proxy $Proxy -SkipInstall:$SkipInstall
} else {
    & $bootstrapRobotFrameworkPath -SkipInstall:$SkipInstall
}
