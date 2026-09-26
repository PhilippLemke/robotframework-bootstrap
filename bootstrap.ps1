param (
    [string]$Proxy,
    [switch]$SkipInstall,
    # Deploy exactly this release (e.g. v1.0.5) instead of the latest one
    [string]$Version,
    # Salt version to install on machines without Salt (e.g. 3006.19, or "latest")
    [string]$SaltVersion = "3006.19"
)

$repo = "PhilippLemke/robotframework-bootstrap"
$saltFolderPath = "C:\Program Files\Salt Project\Salt"
$tempFolderPath = "C:\Temp"

# Without -Proxy, fall back to a $Proxy variable set in the calling session (hidden in here by the
# parameter of the same name, so read from the caller's scope) or an environment variable Proxy,
# and treat it exactly as if it had been passed as -Proxy.
if (-not $Proxy) {
    # Started via -File there is no caller scope at all, which Get-Variable reports as an error
    try {
        $callerProxy = Get-Variable -Name Proxy -Scope 1 -ValueOnly -ErrorAction Stop
    } catch {
        $callerProxy = $null
    }
    if ($callerProxy) {
        $Proxy = $callerProxy
        Write-Host "Proxy set via env variable `$Proxy: $Proxy"
    } elseif ($env:Proxy) {
        $Proxy = $env:Proxy
        Write-Host "Proxy set via env variable `$env:Proxy: $Proxy"
    }
}

# A proxy must be an absolute http(s) URI with a host. Checking the scheme matters, because e.g.
# "myproxy:3128" parses as a valid URI with the scheme "myproxy".
function Test-ProxyFormat {
    param (
        [string]$Proxy
    )

    $uri = $null
    return [System.Uri]::TryCreate($Proxy, [System.UriKind]::Absolute, [ref]$uri) -and
        $uri.Scheme -in @('http', 'https') -and
        [bool]$uri.Host
}

# Quick TCP connectivity check against a host:port, with a short timeout
function Test-TcpConnection {
    param (
        [string]$ComputerName,
        [int]$Port,
        [int]$TimeoutMs = 3000
    )

    $tcpClient = New-Object System.Net.Sockets.TcpClient
    try {
        $asyncResult = $tcpClient.BeginConnect($ComputerName, $Port, $null, $null)
        return $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMs) -and $tcpClient.Connected
    } catch {
        return $false
    } finally {
        $tcpClient.Close()
    }
}

# Catch a malformed proxy (e.g. a leftover placeholder like http://myproxy:port) or one that isn't
# reachable here with one clear message, instead of every download below failing on it.
while ($Proxy) {
    if (-not (Test-ProxyFormat -Proxy $Proxy)) {
        Write-Host "Proxy entry seems to be invalid: $Proxy" -ForegroundColor Red
        Write-Host "Expected format: http://host:port"
    } elseif (-not (Test-TcpConnection -ComputerName ([System.Uri]$Proxy).Host -Port ([System.Uri]$Proxy).Port)) {
        Write-Host "Proxy is not reachable within 3 seconds: $Proxy" -ForegroundColor Red
        if (Test-TcpConnection -ComputerName "github.com" -Port 443) {
            Write-Host "A direct connection to github.com works."
        } else {
            Write-Host "A direct connection to github.com doesn't work either."
        }
    } else {
        break
    }

    switch (Read-Host "[r] Re-specify the proxy   [c] Continue without proxy   [a] Abort") {
        'r' {
            do {
                $Proxy = Read-Host "Proxy"
            } while (-not $Proxy)
        }
        'c' {
            $Proxy = $null
        }
        'a' {
            exit 1
        }
    }
}

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
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -Proxy $Proxy -ProxyUseDefaultCredentials -ErrorAction Stop
    } else {
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -ErrorAction Stop
    }
}

# Look up the highest "vX.Y.Z" git tag for $repo via the GitHub API (no git CLI required on the
# target machine at this point). Falls back to master if the lookup fails or no tags exist yet.
function Get-LatestTag {
    param (
        [string]$repo
    )

    $uri = "https://api.github.com/repos/$repo/tags?per_page=100"

    try {
        if ($Proxy) {
            $tags = Invoke-RestMethod -Uri $uri -Proxy $Proxy -ProxyUseDefaultCredentials -Headers @{ "User-Agent" = "robotframework-bootstrap" }
        } else {
            $tags = Invoke-RestMethod -Uri $uri -Headers @{ "User-Agent" = "robotframework-bootstrap" }
        }
    } catch {
        Write-Host "Could not resolve the latest release tag ($($_.Exception.Message)). Falling back to master." -ForegroundColor Yellow
        return $null
    }

    # The API doesn't order tags by version (v1.0.10 can end up behind v1.0.9), so pick the
    # highest one here. Tags that aren't a version number are ignored.
    $latestTag = $null
    $latestVersion = $null
    foreach ($tag in $tags) {
        $version = $null
        if ([version]::TryParse($tag.name.TrimStart('v'), [ref]$version) -and (-not $latestVersion -or $version -gt $latestVersion)) {
            $latestTag = $tag.name
            $latestVersion = $version
        }
    }
    return $latestTag
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

# Download the bootstrap scripts from the resolved release, not a possibly-stale local copy. If
# that fails, stop: running a leftover copy from an earlier run would deploy an unknown version.
try {
    Invoke-Download -Uri "https://raw.githubusercontent.com/$repo/$ref/bootstrap-robotframework.ps1" -OutFile $bootstrapRobotFrameworkPath
    Invoke-Download -Uri "https://raw.githubusercontent.com/$repo/$ref/bootstrap-salt.ps1" -OutFile $bootstrapSaltPath
} catch {
    Write-Host "FAILED" -ForegroundColor Red
    Write-Host "Could not download the bootstrap scripts ($($_.Exception.Message))."
    Write-Host "Aborting: please fix connectivity issues and start deployment again."
    exit 1
}

# Run the Salt bootstrap script if the Salt folder does not exist
if (-not (Test-Path -Path $saltFolderPath)) {
    Write-Host "Salt installation not detected. Running bootstrap-salt.ps1 (Salt $SaltVersion)..."
    # bootstrap-salt.ps1 reports errors via its exit code; don't let a stale one from earlier count
    $global:LASTEXITCODE = 0
    if ($Proxy) {
        & $bootstrapSaltPath -RunService false -Version $SaltVersion -p $Proxy -IgnoreSSL
    } else {
        & $bootstrapSaltPath -RunService false -Version $SaltVersion
    }

    # Everything after this relies on Salt, so stop here if it didn't get installed (e.g. an
    # unknown -SaltVersion) instead of deploying a setup that can't run.
    if ($global:LASTEXITCODE -ne 0 -or -not (Test-Path -Path (Join-Path $saltFolderPath "salt-call.exe"))) {
        Write-Host "FAILED" -ForegroundColor Red
        Write-Host "Salt $SaltVersion could not be installed (see the output of bootstrap-salt.ps1 above)."
        Write-Host "Aborting: nothing has been deployed."
        exit 1
    }
} else {
    Write-Host "Salt installation detected at $saltFolderPath. Skipping Salt installation steps."
    # An existing installation is never upgraded, so an explicit -SaltVersion has no effect here
    if ($PSBoundParameters.ContainsKey('SaltVersion')) {
        Write-Host "-SaltVersion $SaltVersion is ignored, because Salt is already installed." -ForegroundColor Yellow
    }
}

# Only pass the options that are actually set, so the call also works with a latest release that
# predates them. A requested -Version is resolved by bootstrap-robotframework.ps1 itself.
$bootstrapArgs = @{}
if ($Proxy) {
    $bootstrapArgs.Proxy = $Proxy
}
if ($SkipInstall) {
    $bootstrapArgs.SkipInstall = $true
}
if ($Version) {
    $bootstrapArgs.Version = $Version
}

Write-Host "Running bootstrap-robotframework.ps1 ($ref)..."
& $bootstrapRobotFrameworkPath @bootstrapArgs
