# Advanced script: unknown parameters are rejected instead of silently ignored, and -Verbose works
[CmdletBinding()]
param (
    # Proxy as http://host:port (credentials may be included as http://user:password@host:port),
    # or "none". Saved to proxy.conf; without it the saved proxy is used or asked for.
    [string]$Proxy,
    # Basic auth for the proxy. Without -ProxyPassword the password is asked for.
    [string]$ProxyUser,
    [string]$ProxyPassword,
    [switch]$SkipInstall,
    # Deploy exactly this release (e.g. v1.0.5) instead of the latest one
    [string]$Version,
    # Salt version to install on machines without Salt (e.g. 3006.19, or "latest")
    [string]$SaltVersion = "3006.19",
    # S3 settings for cloud.conf, passed on to bootstrap-robotframework.ps1. If any of them is
    # given, the missing ones and the credentials are asked for interactively.
    [string]$S3Bucket,
    [string]$S3ServiceUrl,
    [string]$S3Location,
    [ValidateSet('True', 'False')]
    [string]$S3PathStyle,
    # Client role of this machine, passed on to bootstrap-robotframework.ps1
    [ValidateSet('coding', 'execution')]
    [string]$ClientRole,
    # Don't sync and install the pip packages from S3, passed on to bootstrap-robotframework.ps1
    [switch]$SkipPip
)

$repo = "PhilippLemke/robotframework-bootstrap"
$saltFolderPath = "C:\Program Files\Salt Project\Salt"
$tempFolderPath = "C:\Temp"

# Allow the downloaded scripts to run. A policy set by Group Policy overrides this with an error
# that changes nothing for this run, so it isn't shown.
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue

# Set the security protocol to TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#region Proxy - keep identical in bootstrap.ps1 and bootstrap-robotframework.ps1
# proxy.conf is the only place the proxy is defined. Salt reads it as minion config, the scripts
# read it for their own downloads and for the AWS CLI/pip. "No proxy" is saved as an empty
# proxy_host, so no later run asks again.
$proxyConfPath = "C:\RF-Bootstrap\salt-data\conf\minion.d\proxy.conf"
$proxyLegacyConfPath = "C:\RF-Bootstrap\salt-data\conf\minion.d\cloud.conf"
$proxyCheckUrl = "https://api.github.com"
# The resolved proxy: "http://host:port" (or $null) and a PSCredential for Basic auth (or $null)
$ProxyUrl = $null
$ProxyCred = $null

# Quote a value for YAML, so credentials with special characters are read back unchanged
function ConvertTo-YamlString {
    param (
        [string]$value
    )
    return "'" + ($value -replace "'", "''") + "'"
}

# Read back a value written by ConvertTo-YamlString (or a plain/double-quoted one)
function ConvertFrom-YamlString {
    param (
        [string]$value
    )
    if ($value.Length -ge 2 -and $value.StartsWith("'") -and $value.EndsWith("'")) {
        return $value.Substring(1, $value.Length - 2) -replace "''", "'"
    }
    return $value.Trim('"')
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

function New-ProxyCredential {
    param (
        [string]$user,
        [string]$password
    )
    # NetworkCredential also accepts an empty password, unlike ConvertTo-SecureString
    $securePassword = (New-Object System.Net.NetworkCredential('', $password)).SecurePassword
    return New-Object System.Management.Automation.PSCredential($user, $securePassword)
}

# Parse a proxy as given by the user: "none", http://host:port or http://user:password@host:port
# (URL-encoded credentials). Returns @{ Url; Credential }, with Url $null for "none", or $null if
# the format is invalid.
function ConvertFrom-ProxyInput {
    param (
        [string]$value
    )

    if ($value -eq 'none') {
        return @{ Url = $null; Credential = $null }
    }

    # Checking the scheme matters, because e.g. "myproxy:3128" parses as a URI with scheme "myproxy"
    $uri = $null
    if (-not [System.Uri]::TryCreate($value, [System.UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -notin @('http', 'https') -or -not $uri.Host) {
        return $null
    }

    $credential = $null
    if ($uri.UserInfo) {
        $user, $password = $uri.UserInfo -split ':', 2
        $credential = New-ProxyCredential -user ([System.Uri]::UnescapeDataString($user)) -password ([System.Uri]::UnescapeDataString("$password"))
    }
    return @{ Url = "http://$($uri.Host):$($uri.Port)"; Credential = $credential }
}

# Proxy settings of proxy.conf as @{ Url; Credential }, or $null if there is no proxy.conf
function Read-ProxyConf {
    if (-not (Test-Path -Path $proxyConfPath)) {
        return $null
    }

    $values = @{}
    foreach ($line in Get-Content -Path $proxyConfPath) {
        if ($line -match '^\s*(proxy_host|proxy_port|proxy_username|proxy_password)\s*:\s*(.*?)\s*$') {
            $values[$Matches[1]] = ConvertFrom-YamlString -value $Matches[2]
        }
    }

    if (-not $values['proxy_host'] -or -not $values['proxy_port'] -or $values['proxy_port'] -eq '0') {
        return @{ Url = $null; Credential = $null }
    }
    $credential = $null
    if ($values['proxy_username']) {
        $credential = New-ProxyCredential -user $values['proxy_username'] -password $values['proxy_password']
    }
    return @{ Url = "http://$($values['proxy_host']):$($values['proxy_port'])"; Credential = $credential }
}

# Save the proxy to proxy.conf; without a Url it is saved as "no proxy"
function Write-ProxyConf {
    param (
        [string]$Url,
        [PSCredential]$Credential
    )

    $lines = @("# Proxy for bootstrap.ps1, bootstrap-robotframework.ps1 and Salt. Change it with")
    $lines += "# bootstrap.ps1 -Proxy http://host:port [-ProxyUser ... -ProxyPassword ...] or -Proxy none."
    if ($Url) {
        $uri = [System.Uri]$Url
        $lines += "proxy_host: $(ConvertTo-YamlString -value $uri.Host)"
        $lines += "proxy_port: $($uri.Port)"
        if ($Credential) {
            $lines += "proxy_username: $(ConvertTo-YamlString -value $Credential.UserName)"
            $lines += "proxy_password: $(ConvertTo-YamlString -value $Credential.GetNetworkCredential().Password)"
        }
    } else {
        $lines += "proxy_host: ''"
        $lines += "proxy_port: 0"
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Path $proxyConfPath) | Out-Null
    # UTF-8 without BOM, a BOM would end up in front of the first key when Salt reads the file
    [System.IO.File]::WriteAllLines($proxyConfPath, [string[]]$lines, (New-Object System.Text.UTF8Encoding $false))
}

# Releases before v1.6.0 kept the proxy in cloud.conf (proxy_*, s3.proxy_*). Move it to proxy.conf
# unless that already exists, and remove the proxy lines from cloud.conf either way.
function Move-LegacyProxyConf {
    if (-not (Test-Path -Path $proxyLegacyConfPath)) {
        return
    }

    $values = @{}
    $keptLines = @()
    foreach ($line in Get-Content -Path $proxyLegacyConfPath) {
        if ($line -match '^\s*(s3\.)?(proxy_\w+)\s*:\s*(.*?)\s*$') {
            # Plain proxy_* wins over s3.proxy_*, proxy_user was the old name of proxy_username
            $key = $Matches[2] -replace '^proxy_user$', 'proxy_username'
            if (-not $Matches[1] -or -not $values.ContainsKey($key)) {
                $values[$key] = ConvertFrom-YamlString -value $Matches[3]
            }
        } else {
            $keptLines += $line
        }
    }
    if ($values.Count -eq 0) {
        return
    }

    if (-not (Test-Path -Path $proxyConfPath)) {
        $url = $null
        $credential = $null
        if ($values['proxy_host'] -and $values['proxy_port'] -and $values['proxy_port'] -ne '0') {
            $url = "http://$($values['proxy_host']):$($values['proxy_port'])"
            if ($values['proxy_username']) {
                $credential = New-ProxyCredential -user $values['proxy_username'] -password $values['proxy_password']
            }
        }
        Write-ProxyConf -Url $url -Credential $credential
        Write-Host "Proxy settings moved from cloud.conf to $proxyConfPath."
    } else {
        Write-Host "Old proxy settings removed from cloud.conf, $proxyConfPath is used instead."
    }
    [System.IO.File]::WriteAllLines($proxyLegacyConfPath, [string[]]$keptLines, (New-Object System.Text.UTF8Encoding $false))
}

# Parameters for Invoke-WebRequest/Invoke-RestMethod to go through the resolved proxy
function Get-ProxyParams {
    $params = @{}
    if ($ProxyUrl) {
        $params.Proxy = $ProxyUrl
        if ($ProxyCred) {
            $params.ProxyCredential = $ProxyCred
        }
    }
    return $params
}

# Human-readable description of a proxy, without the password
function Format-Proxy {
    param (
        [string]$Url,
        [PSCredential]$Credential
    )
    if (-not $Url) {
        return "none"
    }
    if ($Credential) {
        return "$Url (user $($Credential.UserName))"
    }
    return $Url
}

# Check a proxy with a request to api.github.com through it. Returns @{ Result; Message }, Result
# being "ok", "unreachable" (no TCP connection), "auth" (HTTP 407, credentials missing or rejected)
# or "warning" (the proxy answered, but the test request failed for another reason).
function Test-ProxyConnection {
    param (
        [string]$Url,
        [PSCredential]$Credential
    )

    $uri = [System.Uri]$Url
    if (-not (Test-TcpConnection -ComputerName $uri.Host -Port $uri.Port)) {
        return @{ Result = "unreachable"; Message = "No connection to $($uri.Host):$($uri.Port) within 3 seconds." }
    }

    $params = @{ Proxy = $Url }
    if ($Credential) {
        $params.ProxyCredential = $Credential
    }
    try {
        Invoke-WebRequest -Uri $proxyCheckUrl -Method Head -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop @params | Out-Null
    } catch {
        $response = $_.Exception.Response
        if (($response -and [int]$response.StatusCode -eq 407) -or $_.Exception.Message -match '\b407\b') {
            return @{ Result = "auth"; Message = "407 Proxy Authentication Required: credentials missing or rejected." }
        }
        return @{ Result = "warning"; Message = $_.Exception.Message }
    }
    return @{ Result = "ok"; Message = $null }
}

# Ask for the proxy and its credentials. Enter means no proxy / no authentication.
function Read-ProxySettings {
    while ($true) {
        $answer = Read-Host "Proxy, e.g. http://myproxy:3128 (Enter = none)"
        if (-not $answer) {
            return @{ Url = $null; Credential = $null }
        }
        $settings = ConvertFrom-ProxyInput -value $answer
        if ($settings) {
            break
        }
        Write-Host "Invalid proxy: $answer (expected http://host:port)" -ForegroundColor Red
    }

    if ($settings.Url -and -not $settings.Credential) {
        $user = Read-Host "Proxy user (Enter = no authentication)"
        if ($user) {
            $password = [System.Net.NetworkCredential]::new('', (Read-Host "Proxy password" -AsSecureString)).Password
            $settings.Credential = New-ProxyCredential -user $user -password $password
        }
    }
    return $settings
}

# Resolve the proxy for this run and save it to proxy.conf: from the parameters if given, else from
# proxy.conf, else asked for. A proxy that is unreachable or rejects the credentials can be
# re-entered, dropped or the run aborted. Sets $script:ProxyUrl and $script:ProxyCred.
function Resolve-Proxy {
    param (
        [string]$Proxy,
        [string]$ProxyUser,
        [string]$ProxyPassword
    )

    Move-LegacyProxyConf

    $settings = $null
    $save = $true
    if ($Proxy) {
        $settings = ConvertFrom-ProxyInput -value $Proxy
        if (-not $settings) {
            Write-Host "Invalid -Proxy: $Proxy (expected http://host:port or none)" -ForegroundColor Red
            $settings = Read-ProxySettings
        } elseif ($settings.Url -and $ProxyUser) {
            if (-not $ProxyPassword) {
                $ProxyPassword = [System.Net.NetworkCredential]::new('', (Read-Host "Proxy password for $ProxyUser" -AsSecureString)).Password
            }
            $settings.Credential = New-ProxyCredential -user $ProxyUser -password $ProxyPassword
        }
    } else {
        if ($ProxyUser) {
            Write-Host "-ProxyUser is ignored without -Proxy." -ForegroundColor Yellow
        }
        $settings = Read-ProxyConf
        if ($settings) {
            $save = $false
            Write-Host "Proxy: $(Format-Proxy -Url $settings.Url -Credential $settings.Credential) (from proxy.conf)"
        } else {
            $settings = Read-ProxySettings
        }
    }

    while ($settings.Url) {
        Write-Host -NoNewline "Testing proxy $(Format-Proxy -Url $settings.Url -Credential $settings.Credential) via $($proxyCheckUrl): "
        $test = Test-ProxyConnection -Url $settings.Url -Credential $settings.Credential
        if ($test.Result -eq "ok") {
            Write-Host "OK" -ForegroundColor Green
            break
        }
        if ($test.Result -eq "warning") {
            Write-Host "WARNING" -ForegroundColor Yellow
            Write-Host "The proxy answered, but the test request failed: $($test.Message)" -ForegroundColor Yellow
            Write-Host "Continuing with this proxy, downloads may fail."
            break
        }
        Write-Host "FAILED" -ForegroundColor Red
        Write-Host $test.Message -ForegroundColor Red
        if ($test.Result -eq "unreachable") {
            if (Test-TcpConnection -ComputerName "github.com" -Port 443) {
                Write-Host "A direct connection to github.com works."
            } else {
                Write-Host "A direct connection to github.com doesn't work either."
            }
        }

        $answer = Read-Host "[r] Re-enter proxy   [c] Continue without proxy   [a] Abort"
        if ($answer -eq 'r') {
            $settings = Read-ProxySettings
            $save = $true
        } elseif ($answer -eq 'c') {
            $settings = @{ Url = $null; Credential = $null }
            $save = $true
        } elseif ($answer -eq 'a') {
            exit 1
        }
    }

    if ($save) {
        Write-ProxyConf -Url $settings.Url -Credential $settings.Credential
        Write-Host "Proxy settings saved to $($proxyConfPath): $(Format-Proxy -Url $settings.Url -Credential $settings.Credential)"
    }
    $script:ProxyUrl = $settings.Url
    $script:ProxyCred = $settings.Credential
}
#endregion

Resolve-Proxy -Proxy $Proxy -ProxyUser $ProxyUser -ProxyPassword $ProxyPassword
$proxyParams = Get-ProxyParams

# Create the temporary directory if it doesn't exist
New-Item -ItemType Directory -Force -Path $tempFolderPath | Out-Null

function Invoke-Download {
    param (
        [string]$Uri,
        [string]$OutFile
    )

    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -ErrorAction Stop @proxyParams
}

# Look up the highest "vX.Y.Z" git tag for $repo via the GitHub API (no git CLI required on the
# target machine at this point). Falls back to master if the lookup fails or no tags exist yet.
function Get-LatestTag {
    param (
        [string]$repo
    )

    $uri = "https://api.github.com/repos/$repo/tags?per_page=100"

    try {
        $tags = Invoke-RestMethod -Uri $uri -Headers @{ "User-Agent" = "robotframework-bootstrap" } @proxyParams
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
    if ($ProxyUrl) {
        $saltProxyArgs = @{ Proxy = $ProxyUrl }
        # bootstrap-salt.ps1 of releases before v1.6.0 has no -ProxyCredential
        if ($ProxyCred -and (Get-Command -Name $bootstrapSaltPath).Parameters.ContainsKey('ProxyCredential')) {
            $saltProxyArgs.ProxyCredential = $ProxyCred
        }
        & $bootstrapSaltPath -RunService false -Version $SaltVersion -IgnoreSSL @saltProxyArgs
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
# -Proxy is only for releases before v1.6.0, later ones read proxy.conf and ignore it.
$bootstrapArgs = @{}
if ($ProxyUrl) {
    $bootstrapArgs.Proxy = $ProxyUrl
}
if ($SkipInstall) {
    $bootstrapArgs.SkipInstall = $true
}
if ($SkipPip) {
    $bootstrapArgs.SkipPip = $true
}
if ($VerbosePreference -eq 'Continue') {
    $bootstrapArgs.Verbose = $true
}
if ($Version) {
    $bootstrapArgs.Version = $Version
}
foreach ($name in 'S3Bucket', 'S3ServiceUrl', 'S3Location', 'S3PathStyle', 'ClientRole') {
    if ($PSBoundParameters[$name]) {
        $bootstrapArgs[$name] = $PSBoundParameters[$name]
    }
}

Write-Host "Running bootstrap-robotframework.ps1 ($ref)..."
& $bootstrapRobotFrameworkPath @bootstrapArgs
