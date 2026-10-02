# Advanced script: unknown parameters are rejected instead of silently ignored, and -Verbose works
[CmdletBinding()]
param (
    # Only for relaunches from releases before v1.6.0 and machines without proxy.conf: the proxy is
    # set up with bootstrap.ps1 (or asked for) and read from proxy.conf.
    [string]$Proxy,
    [switch]$AlreadyRelaunched,
    [switch]$SkipInstall,
    # Deploy exactly this release (e.g. v1.0.5) instead of the latest one
    [string]$Version,
    # S3 settings for cloud.conf. If any of them is given, the missing ones and the credentials
    # (s3.keyid, s3.key - never passed as parameters) are asked for interactively.
    [string]$S3Bucket,
    [string]$S3ServiceUrl,
    [string]$S3Location,
    [ValidateSet('True', 'False')]
    [string]$S3PathStyle,
    # Client role of this machine; saved, so later runs don't ask again
    [ValidateSet('coding', 'execution')]
    [string]$ClientRole,
    # Don't sync and install the pip packages from S3 after the Salt steps
    [switch]$SkipPip
)

# Current released version of this script. Bump this by hand every time a new git tag is cut.
$scriptVersion = "v1.5.2"

# Define the local path to save the installer
$defRFInstallerPath = "C:\RF-Bootstrap"
$defRepo = "PhilippLemke/robotframework-bootstrap"
$gitSnap = "$defRFInstallerPath\git-snap"
$cloudConfPath = "$defRFInstallerPath\salt-data\conf\minion.d\cloud.conf"
$cloudConfBackupPath = "$defRFInstallerPath\backup\cloud.conf"
$cloudConfRestored = $false
$rfClientLocalPath = "$defRFInstallerPath\salt-data\srv\pillar\rf-client-local.sls"
$clientRolePath = "$defRFInstallerPath\salt-data\srv\pillar\client-role.sls"
$pipPkgPath = "$defRFInstallerPath\pkgs\pip"
$awsCliPath = "C:\Program Files\Amazon\AWSCLIV2\aws.exe"
$defaultPythonHome = "C:\Program Files\Python310"
$saltCallPath = "$defRFInstallerPath\salt-app\salt-call.exe"
$saltConfDir = "$defRFInstallerPath\salt-data\conf"
# Left over by releases before v1.6.0, would override proxy.conf
$noProxyConfPath = "$defRFInstallerPath\salt-data\conf\minion.d\zz-no-proxy.conf"

# Print a section header to visually group the cmd output
function Write-Section {
    param (
        [string]$Title
    )
    Write-Output ""
    Write-Host "# $Title" -ForegroundColor Cyan
}

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

# Look up the highest "vX.Y.Z" git tag for $repo via the GitHub API (no git CLI required)
function Get-LatestTag {
    param (
        [string]$repo
    )

    $uri = "https://api.github.com/repos/$repo/tags?per_page=100"

    try {
        $proxyParams = Get-ProxyParams
        $tags = Invoke-RestMethod -Uri $uri -Headers @{ "User-Agent" = "robotframework-bootstrap" } @proxyParams
    } catch {
        Write-Host "Could not check for a newer version ($($_.Exception.Message)). Continuing with the current version ($scriptVersion)."
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

# Compare two "vX.Y.Z" tags. Only a strictly newer tag counts, so a script that is ahead of the
# latest tag (e.g. before its release is tagged) never "updates" to an older version. Tags that
# don't parse as a version are never treated as newer.
function Test-NewerVersion {
    param (
        [string]$tag,
        [string]$current
    )

    $tagVersion = $null
    $currentVersion = $null
    if (-not [version]::TryParse($tag.TrimStart('v'), [ref]$tagVersion) -or
        -not [version]::TryParse($current.TrimStart('v'), [ref]$currentVersion)) {
        return $false
    }

    return $tagVersion -gt $currentVersion
}

# Download the script of release $tag and hand execution off to it, so that release's code does
# the deployment instead of this run. Used for self-updates and for -Version. Guarded by
# -AlreadyRelaunched so a stale $scriptVersion can never cause more than one relaunch.
function Invoke-SelfUpdate {
    param (
        [string]$repo,
        [string]$tag
    )

    Write-Host "Downloading $tag (currently running $scriptVersion) and relaunching..."

    $newScriptPath = Join-Path $env:TEMP "bootstrap-robotframework-$tag.ps1"
    $newScriptUrl = "https://raw.githubusercontent.com/$repo/$tag/bootstrap-robotframework.ps1"

    try {
        $proxyParams = Get-ProxyParams
        Invoke-WebRequest -Uri $newScriptUrl -OutFile $newScriptPath -ErrorAction Stop @proxyParams
    } catch {
        Write-Host "Failed to download $tag ($($_.Exception.Message))."
        return $false
    }

    $argString = "-NoProfile -ExecutionPolicy Bypass -File `"$newScriptPath`" -AlreadyRelaunched"
    # Releases before v1.6.0 don't read proxy.conf, they only take -Proxy (without credentials)
    if ($ProxyUrl -and (Test-NewerVersion -tag "v1.6.0" -current $tag)) {
        $argString += " -Proxy `"$ProxyUrl`""
    }
    # Releases before v1.1.0 don't know -SkipInstall (and never install software anyway)
    if ($SkipInstall) {
        if (Test-NewerVersion -tag "v1.1.0" -current $tag) {
            Write-Host "$tag has no software installation step, -SkipInstall is not needed."
        } else {
            $argString += " -SkipInstall"
        }
    }

    # The S3 parameters exist from v1.3.0 on
    if ($S3Bucket -or $S3ServiceUrl -or $S3Location -or $S3PathStyle) {
        $s3Args = [ordered]@{ S3Bucket = $S3Bucket; S3ServiceUrl = $S3ServiceUrl; S3Location = $S3Location; S3PathStyle = $S3PathStyle }
        if (Test-NewerVersion -tag "v1.3.0" -current $tag) {
            Write-Host "$tag doesn't support the S3 parameters, they are ignored." -ForegroundColor Yellow
        } else {
            foreach ($name in $s3Args.Keys) {
                if ($s3Args[$name]) {
                    $argString += " -$name `"$($s3Args[$name])`""
                }
            }
        }
    }

    # -ClientRole exists from v1.4.0 on
    if ($ClientRole) {
        if (Test-NewerVersion -tag "v1.4.0" -current $tag) {
            Write-Host "$tag doesn't support -ClientRole, it is ignored." -ForegroundColor Yellow
        } else {
            $argString += " -ClientRole $ClientRole"
        }
    }

    # -SkipPip exists from v1.5.0 on (older releases don't install pip packages at all)
    if ($SkipPip) {
        if (Test-NewerVersion -tag "v1.5.0" -current $tag) {
            Write-Host "$tag has no pip package step, -SkipPip is not needed."
        } else {
            $argString += " -SkipPip"
        }
    }

    # Keep verbose mode (older releases without CmdletBinding just ignore it)
    if ($VerbosePreference -eq 'Continue') {
        $argString += " -Verbose"
    }

    # Wait for the relaunched run so it keeps the console to itself (a caller like the README
    # one-liner's trailing `cmd` would otherwise start and compete for input) and pass on its
    # exit code.
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList $argString -NoNewWindow -Wait -PassThru
    $script:relaunchExitCode = $process.ExitCode
    return $true
}

function Download-Repo {
    param (
        [string]$tmp_folder,
        [string]$repo,
        [string]$tag
    )

    # Pull the exact tagged snapshot, so a version number always refers to a fixed, reproducible
    # set of salt-data/states rather than whatever master currently happens to be.
    $url = "https://github.com/$repo/archive/refs/tags/$tag.zip"

    # Construct the output file path
    $outputFilePath = Join-Path -Path $tmp_folder -ChildPath "$($repo.Split('/')[-1]).zip"

    # Start from a clean slate: a leftover extracted folder from a previous tag (which has a
    # different folder name) would otherwise sit next to the new one, or - if this download fails
    # - get silently picked up and deployed as if it were current.
    if (Test-Path -Path $tmp_folder) {
        Get-ChildItem -Path $tmp_folder -Force | Remove-Item -Recurse -Force
    }

    try {
        $proxyParams = Get-ProxyParams
        Invoke-WebRequest -Uri $url -OutFile $outputFilePath -ErrorAction Stop @proxyParams

        Expand-Archive -Path $outputFilePath -DestinationPath $tmp_folder -Force -ErrorAction Stop
    } catch {
        Write-Host "FAILED" -ForegroundColor Red
        Write-Host "Could not download/extract $url ($($_.Exception.Message))."
        return $false
    }

    return $true
}

# Back up an existing cloud.conf before it gets overwritten by the repository's example file
function Backup-CloudConf {
    if (Test-Path -Path $cloudConfPath) {
        Write-Output "Existing cloud.conf found, backing it up to $cloudConfBackupPath"
        Copy-Item -Path $cloudConfPath -Destination $cloudConfBackupPath -Force
    }
}

# Restore the previously backed up cloud.conf over the repository's example file
function Restore-CloudConf {
    if (Test-Path -Path $cloudConfBackupPath) {
        Write-Output "Restoring previous cloud.conf from $cloudConfBackupPath"
        Copy-Item -Path $cloudConfBackupPath -Destination $cloudConfPath -Force
        Remove-Item -Path $cloudConfBackupPath -Force
        $script:cloudConfRestored = $true
    }
}

# Create the machine-specific pillar override file if it doesn't exist yet. It isn't part of the
# repository, so deploying salt-data never overwrites it, while rf-client.sls itself stays
# updatable with each release.
function New-RfClientLocal {
    if (Test-Path -Path $rfClientLocalPath) {
        Write-Output "Local pillar overrides found: $rfClientLocalPath"
        return
    }

    Write-Output "Creating local pillar override template: $rfClientLocalPath"
    $template = @(
        "# Machine-specific overrides for rf-client.sls / software-versions.sls."
        "# This file is not part of the repository and is never overwritten by the bootstrap."
        "# Dicts are merged with the defaults, lists (e.g. vscode-extensions) replace them completely."
        "#"
        "# Examples:"
        "#client-role: execution"
        "#"
        "#apps-coding:"
        "#  vscode:"
        "#    version: 1.138.0"
        "#"
        "#vscode-extensions:"
        "#  - d-biehl.robotcode@2.7.0"
    )
    Set-Content -Path $rfClientLocalPath -Value $template -Encoding ASCII
}

# Create the client role pillar file if it doesn't exist yet, with comments only, so the pillar
# top file never points to a missing file. The role itself is written once it is chosen.
function New-ClientRoleFile {
    if (Test-Path -Path $clientRolePath) {
        return
    }

    Set-Content -Path $clientRolePath -Encoding ASCII -Value @(
        "# Client role of this machine (coding or execution), written by bootstrap-robotframework.ps1."
        "# This file is not part of the repository and is never overwritten by the bootstrap."
        "# No role chosen yet."
    )
}

# Read the active (not commented out) client-role from a pillar file, or $null
function Get-PillarClientRole {
    param (
        [string]$path
    )

    if (Test-Path -Path $path) {
        foreach ($line in Get-Content -Path $path) {
            if ($line -match '^\s*client-role\s*:\s*(\S+)') {
                return $Matches[1].Trim("'`"")
            }
        }
    }
    return $null
}

# Save the client role, keeping the file's comment header
function Set-ClientRole {
    param (
        [string]$role
    )

    Set-Content -Path $clientRolePath -Encoding ASCII -Value @(
        "# Client role of this machine (coding or execution), written by bootstrap-robotframework.ps1."
        "# This file is not part of the repository and is never overwritten by the bootstrap."
        "client-role: $role"
    )
}

# Ask for the client role. Enter picks coding.
function Read-ClientRole {
    Write-Host "Client role for this machine:"
    Write-Host "  [c] coding     Robot Framework + VS Code, Greenshot, extensions (default)"
    Write-Host "  [e] execution  Robot Framework runtime only"
    while ($true) {
        switch (Read-Host "Client role [c]") {
            { $_ -in '', 'c', 'coding' } { return 'coding' }
            { $_ -in 'e', 'execution' } { return 'execution' }
        }
    }
}

# Decide the client role for the installation: an active line in rf-client-local.sls wins (as it
# does in Salt), then the saved role, otherwise ask once and save the answer.
function Resolve-ClientRole {
    $localRole = Get-PillarClientRole -path $rfClientLocalPath
    if ($localRole) {
        Write-Output "client-role: $localRole (from rf-client-local.sls)"
        return
    }

    $savedRole = Get-PillarClientRole -path $clientRolePath
    if ($savedRole) {
        Write-Output "client-role: $savedRole (from client-role.sls)"
        return
    }

    $role = Read-ClientRole
    Set-ClientRole -role $role
    Write-Output "client-role: $role (saved in $clientRolePath)"
}

# cloud.conf counts as configured once the S3 credentials are filled in and the bucket is no
# longer the repository's example value.
function Test-CloudConfConfigured {
    if (-not (Test-Path -Path $cloudConfPath)) {
        return $false
    }

    $values = @{}
    foreach ($line in Get-Content -Path $cloudConfPath) {
        if ($line -match '^\s*(s3\.keyid|s3\.key|s3\.bucket):\s*(.*?)\s*$') {
            $values[$Matches[1]] = $Matches[2].Trim("'`"")
        }
    }

    return [bool]($values['s3.keyid'] -and $values['s3.key'] -and $values['s3.bucket'] -and $values['s3.bucket'] -ne 'myBucketName')
}

# Ask for an S3 setting. Enter accepts the default shown in brackets; without a default an answer
# is required.
function Read-S3Setting {
    param (
        [string]$name,
        [string]$default
    )

    while ($true) {
        if ($default) {
            $answer = Read-Host "$name [$default]"
        } else {
            $answer = Read-Host $name
        }
        if ($answer) {
            return $answer
        }
        if ($default) {
            return $default
        }
    }
}

# Ask for an S3 credential without echoing it; an answer is required
function Read-S3Secret {
    param (
        [string]$name
    )

    while ($true) {
        $answer = [System.Net.NetworkCredential]::new('', (Read-Host $name -AsSecureString)).Password
        if ($answer) {
            return $answer
        }
    }
}

# Write a new cloud.conf from the S3 parameters. Missing settings are asked for (with the built-in
# defaults), the credentials are always asked for.
function New-S3CloudConf {
    $settings = [ordered]@{
        's3.bucket'      = @($S3Bucket, $null)
        's3.service_url' = @($S3ServiceUrl, 's3.eu-central-1.amazonaws.com')
        's3.location'    = @($S3Location, 'eu-central-1')
        's3.path_style'  = @($S3PathStyle, 'True')
    }

    $lines = @()
    foreach ($key in $settings.Keys) {
        $given, $default = $settings[$key]
        if ($given) {
            $value = $given
            Write-Output "${key}: $value"
        } else {
            $value = Read-S3Setting -name $key -default $default
        }
        # path_style is a YAML boolean, everything else is written as a quoted string
        if ($key -eq 's3.path_style') {
            $lines += "${key}: $value"
        } else {
            $lines += "${key}: $(ConvertTo-YamlString -value $value)"
        }
    }
    $lines += "s3.keyid: $(ConvertTo-YamlString -value (Read-S3Secret -name 's3.keyid'))"
    $lines += "s3.key: $(ConvertTo-YamlString -value (Read-S3Secret -name 's3.key'))"

    # UTF-8 without BOM, a BOM would end up in front of the first key when Salt reads the file
    [System.IO.File]::WriteAllLines($cloudConfPath, [string[]]$lines, (New-Object System.Text.UTF8Encoding $false))
    Write-Output "New cloud.conf written to $cloudConfPath."
}

# With an existing cloud.conf from before this run, let the user choose between keeping it and
# replacing it with a new one built from the S3 parameters. Returns $true to write a new one.
function Confirm-NewS3CloudConf {
    if (-not $cloudConfRestored) {
        return $true
    }

    Write-Host "S3 parameters were given, but an existing cloud.conf was found."
    while ($true) {
        $answer = Read-Host "[e] Use the existing cloud.conf   [n] Create a new one (replaces the whole file)"
        if ($answer -eq 'e') {
            return $false
        }
        if ($answer -eq 'n') {
            return $true
        }
    }
}

# Keep asking until cloud.conf is configured, or the user skips the software installation.
# Returns $true if the installation should run.
function Wait-CloudConfConfigured {
    while (-not (Test-CloudConfConfigured)) {
        Write-Host "cloud.conf still contains the example configuration." -ForegroundColor Yellow
        Write-Host "Please edit before continuing:"
        Write-Host "  $cloudConfPath (s3.keyid, s3.key, s3.bucket)"
        Write-Host "  $rfClientLocalPath (optional, machine-specific overrides of rf-client.sls)"
        $answer = Read-Host "Press Enter when done, or type 'skip' to skip the software installation"
        if ($answer -eq 'skip') {
            return $false
        }
    }
    return $true
}

# Run a single salt-call against the local RF-Bootstrap config. Its output is sent straight to the
# host so it can't end up in the function's return value (see Download-Repo). Returns $true on
# success.
function Invoke-SaltCall {
    param (
        [string[]]$Arguments
    )

    Write-Host ""
    Write-Host "salt-call $($Arguments -join ' ')"
    & $saltCallPath --local "--config-dir=$saltConfDir" --retcode-passthrough @Arguments | Out-Host
    return ($LASTEXITCODE -eq 0)
}

# Print the manual commands, for when the installation is skipped or has to be re-run by hand
function Write-InstallCommands {
    Write-Output "cd /d $defRFInstallerPath\salt-app\"
    Write-Output "salt-call --local --config-dir=$saltConfDir pkg.refresh_db saltenv=cloud"
    Write-Output "salt-call --local --config-dir=$saltConfDir saltutil.sync_all saltenv=cloud"
    Write-Output "salt-call --local --config-dir=$saltConfDir state.apply deploy-rf-client saltenv=cloud -l info"
}

# Locate the AWS CLI: its default install location first, then PATH. Returns $null if missing.
function Get-AwsCliPath {
    if (Test-Path -Path $awsCliPath) {
        return $awsCliPath
    }
    $command = Get-Command -Name aws -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }
    return $null
}

# Ask Salt for python_home, so an override in rf-client-local.sls is respected. Falls back to the
# default if Salt returns nothing.
function Get-PythonHome {
    try {
        $json = & $saltCallPath --local "--config-dir=$saltConfDir" -l quiet --out=json pillar.get python_home 2>$null | Out-String
        $pythonHome = ($json | ConvertFrom-Json).local
    } catch {
        $pythonHome = $null
    }
    if ($pythonHome) {
        return $pythonHome
    }
    return $defaultPythonHome
}

# Read s3.bucket from cloud.conf (surrounding quotes removed)
function Get-CloudConfBucket {
    foreach ($line in Get-Content -Path $cloudConfPath) {
        if ($line -match '^\s*s3\.bucket\s*:\s*(.*?)\s*$') {
            return $Matches[1].Trim("'`"")
        }
    }
    return $null
}


# Define your bootstrap directory structure here
$directoryStructure = @{
    $defRFInstallerPath = @(
        "salt-app",
        "salt-var",
        "git-snap",
        "backup",
        "pkgs/blobs",
        "pkgs/pip"
    )
}

# Function to create directories from the structure
function Create-Directories {
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]$structure
    )

    foreach ($root in $structure.Keys) {
        foreach ($path in $structure[$root]) {
            $fullPath = Join-Path -Path $root -ChildPath $path
            if (-not (Test-Path -Path $fullPath)) {
                Write-Output "Creating directory: $fullPath"
                New-Item -Path $fullPath -ItemType Directory | Out-Null
            }
            else {
                Write-Output "Directory already exists: $fullPath"
            }
        }
    }
}

# The proxy for everything below: proxy.conf, or asked for on a machine without one. A -Proxy from
# a relaunch by an older release only counts as long as there is no proxy.conf yet.
Write-Section "Proxy"
if (Test-Path -Path $noProxyConfPath) {
    Remove-Item -Path $noProxyConfPath -Force
}
Move-LegacyProxyConf
if (Test-Path -Path $proxyConfPath) {
    $Proxy = $null
}
Resolve-Proxy -Proxy $Proxy

# With -Version, deploy exactly that release: hand off to its script unless this is already it.
# The relaunched script is started without -Version, since releases before v1.1.0 don't know it.
# Its $scriptVersion is the requested one and -AlreadyRelaunched skips its own version check.
if ($Version -and -not $AlreadyRelaunched) {
    if (-not $Version.StartsWith('v')) {
        $Version = "v$Version"
    }

    Write-Section "Version Check"
    if ($Version -eq $scriptVersion) {
        Write-Output "Deploying the requested version ($Version)."
    } else {
        Write-Output "Requested version: $Version."
        if (-not (Invoke-SelfUpdate -repo $defRepo -tag $Version)) {
            Write-Output ""
            Write-Output "Aborting: could not download version $Version. Nothing has been deployed."
            exit 1
        }
        Write-Output "Relaunched run ($Version) finished."
        exit $relaunchExitCode
    }
}

# Otherwise check for a newer released version before doing any real work, and hand off to it if
# found. Skipped on the relaunched (already-updated) run, so a stale $scriptVersion can never
# cause more than one relaunch.
if (-not $Version -and -not $AlreadyRelaunched) {
    Write-Section "Version Check"
    $latestTag = Get-LatestTag -repo $defRepo
    if ($latestTag -and (Test-NewerVersion -tag $latestTag -current $scriptVersion)) {
        Write-Output "Newer version available: $latestTag."
        if (Invoke-SelfUpdate -repo $defRepo -tag $latestTag) {
            Write-Output "Relaunched run ($latestTag) finished. Exiting this (outdated) run."
            exit $relaunchExitCode
        }
        Write-Output "Continuing with the current version ($scriptVersion)."
    } else {
        Write-Output "Running the current version ($scriptVersion)."
    }
}

# Call the function to create the directory structure
Write-Section "Create Directories"
Create-Directories -structure $directoryStructure

# Back up a pre-existing cloud.conf before it can be overwritten by the bootstrap run
Write-Section "Backup"
Backup-CloudConf

# Define source and destination paths
Write-Section "Copy"
$sourcePath = "C:\Program Files\Salt Project\Salt"
$destinationPath = $defRFInstallerPath + "\salt-app"

# Check if the source directory exists
if (Test-Path -Path $sourcePath) {

    # Copy the entire contents of the source directory to the destination, including subfolders
    Copy-Item -Path "$sourcePath\*" -Destination $destinationPath -Recurse -Force
    Write-Output "Copied contents from $sourcePath to $destinationPath."
} else {
    Write-Output "Source directory does not exist: $sourcePath"
}

Write-Section "Download"
Write-Output "Download and extract the git repository content ($scriptVersion)"
if (-not (Download-Repo -tmp_folder $gitSnap -repo $defRepo -tag $scriptVersion)) {
    Write-Output ""
    Write-Output "Aborting: could not download release $scriptVersion. Nothing has been deployed."
    exit 1
}

Write-Section "Deploy"
Write-Output "Provide salt-data from git repository to $defRFInstallerPath."
# The extracted folder name depends on the tag (e.g. robotframework-bootstrap-1.0.0), so resolve
# it dynamically instead of assuming a fixed "-master" suffix.
$extractedFolder = Get-ChildItem -Path $gitSnap -Directory | Select-Object -First 1
Copy-Item -Path "$($extractedFolder.FullName)\salt-data" -Destination $defRFInstallerPath -Recurse -Force

# Restore a previously backed up cloud.conf over the example one just deployed above
Restore-CloudConf

if ($cloudConfRestored) {
    Write-Output ""
    Write-Output "NOTE: An existing cloud.conf was found before this run and has been restored to $cloudConfPath after the bootstrap update."
}

# Apply S3 settings passed as parameters, after the previous cloud.conf has been restored
if ($S3Bucket -or $S3ServiceUrl -or $S3Location -or $S3PathStyle) {
    Write-Section "S3 Configuration"
    if (Confirm-NewS3CloudConf) {
        New-S3CloudConf
    } else {
        Write-Output "Using the existing cloud.conf, the S3 parameters are ignored."
    }
}

# Seed the machine-specific pillar overrides after salt-data is in place
New-RfClientLocal
New-ClientRoleFile

# An explicit -ClientRole is saved right away, also with -SkipInstall
if ($ClientRole) {
    Set-ClientRole -role $ClientRole
    Write-Output "client-role $ClientRole saved in $clientRolePath"
    $localRole = Get-PillarClientRole -path $rfClientLocalPath
    if ($localRole -and $localRole -ne $ClientRole) {
        Write-Host "rf-client-local.sls overrides it with client-role: $localRole until that line is removed." -ForegroundColor Yellow
    }
}

if ($SkipInstall) {
    Write-Output ""
    Write-Output "-SkipInstall given: skipping the software installation."
    exit
}

Write-Section "Install Software"
if (-not (Wait-CloudConfConfigured)) {
    Write-Output "Software installation skipped. Run it later with:"
    Write-InstallCommands
    exit
}

Resolve-ClientRole

$saltSteps = @(
    @("pkg.refresh_db", "saltenv=cloud"),
    @("saltutil.sync_all", "saltenv=cloud"),
    @("state.apply", "deploy-rf-client", "saltenv=cloud", "-l", "info")
)
$failedStep = $null
foreach ($step in $saltSteps) {
    if (-not (Invoke-SaltCall -Arguments $step)) {
        $failedStep = $step
        break
    }
}

if ($failedStep) {
    Write-Host "FAILED" -ForegroundColor Red
    Write-Output "salt-call $($failedStep -join ' ') failed. See $defRFInstallerPath\salt-var\salt.log for details."
    exit 1
}

# Pip packages come from the S3 bucket's pip folder and are installed offline. The sync runs the
# AWS CLI directly with the credentials Salt wrote to ~/.aws; download-pip-pkgs-cloud.sls stays
# available as a manual fallback.
if ($SkipPip) {
    Write-Output ""
    Write-Output "-SkipPip given: skipping the pip packages."
} else {
    Write-Section "Pip Packages"
    $aws = Get-AwsCliPath
    if (-not $aws) {
        Write-Output "AWS CLI not found, skipping pip packages."
    } else {
        $bucket = Get-CloudConfBucket
        $python = Join-Path (Get-PythonHome) "python.exe"
        $requirementsPath = Join-Path $pipPkgPath "requirements.txt"
        $pipCommand = "`"$python`" -m pip install --no-index --find-links=`"$pipPkgPath`" -r `"$requirementsPath`""

        # Same proxy as Salt uses (proxy.conf), credentials URL-encoded
        $savedHttpProxy = $env:HTTP_PROXY
        $savedHttpsProxy = $env:HTTPS_PROXY
        if ($ProxyUrl) {
            $envProxy = $ProxyUrl
            if ($ProxyCred) {
                $userInfo = [System.Uri]::EscapeDataString($ProxyCred.UserName) + ":" + [System.Uri]::EscapeDataString($ProxyCred.GetNetworkCredential().Password)
                $envProxy = $ProxyUrl -replace '^http://', "http://$userInfo@"
            }
            $env:HTTP_PROXY = $envProxy
            $env:HTTPS_PROXY = $envProxy
        }

        # Full output only with -Verbose; otherwise it is captured, summarized, and shown on failure
        $showDetails = $VerbosePreference -eq 'Continue'
        Write-Output "aws s3 sync s3://$bucket/pip $pipPkgPath"
        try {
            if ($showDetails) {
                & $aws s3 sync "s3://$bucket/pip" $pipPkgPath | Out-Host
            } else {
                $syncOutput = & $aws s3 sync "s3://$bucket/pip" $pipPkgPath --no-progress 2>&1 | ForEach-Object { "$_" }
            }
            $syncExitCode = $LASTEXITCODE
        } finally {
            $env:HTTP_PROXY = $savedHttpProxy
            $env:HTTPS_PROXY = $savedHttpsProxy
        }

        if ($syncExitCode -ne 0 -and -not $showDetails) {
            $syncOutput | Out-Host
        }

        # Exit code 2 means some files were skipped, but the rest was synced
        if ($syncExitCode -eq 2) {
            Write-Host "aws s3 sync skipped some files, see the output above." -ForegroundColor Yellow
        } elseif ($syncExitCode -ne 0) {
            Write-Host "FAILED" -ForegroundColor Red
            Write-Output "aws s3 sync failed (exit code $syncExitCode). Manual fallback via Salt:"
            Write-Output "  cd /d $defRFInstallerPath\salt-app\"
            Write-Output "  salt-call --local --config-dir=$saltConfDir state.apply download-pip-pkgs-cloud saltenv=cloud -l info"
            Write-Output "  $pipCommand"
            exit 1
        }

        if (-not $showDetails) {
            $downloaded = @($syncOutput | Where-Object { $_ -match '^download: ' }).Count
            $total = @(Get-ChildItem -Path $pipPkgPath -File).Count
            Write-Output "Sync successful: $downloaded file(s) downloaded, $total file(s) in $pipPkgPath."
        }

        if (-not (Test-Path -Path $requirementsPath)) {
            Write-Output "No requirements.txt in $pipPkgPath, skipping pip install."
        } elseif (-not (Test-Path -Path $python)) {
            Write-Host "FAILED" -ForegroundColor Red
            Write-Output "Python not found at $python, cannot install the pip packages."
            exit 1
        } else {
            Write-Output ""
            Write-Output $pipCommand
            if ($showDetails) {
                & $python -m pip install --no-index "--find-links=$pipPkgPath" -r $requirementsPath | Out-Host
            } else {
                $pipOutput = & $python -m pip install --no-index "--find-links=$pipPkgPath" -r $requirementsPath 2>&1 | ForEach-Object { "$_" }
            }
            $pipExitCode = $LASTEXITCODE
            if ($pipExitCode -ne 0) {
                if (-not $showDetails) {
                    $pipOutput | Out-Host
                }
                Write-Host "FAILED" -ForegroundColor Red
                Write-Output "pip install failed (exit code $pipExitCode)."
                exit 1
            }

            if (-not $showDetails) {
                $installedLine = $pipOutput | Where-Object { $_ -match '^Successfully installed ' } | Select-Object -Last 1
                $installed = @()
                if ($installedLine) {
                    $installed = @(($installedLine -replace '^Successfully installed ', '').Trim() -split '\s+')
                }
                $satisfied = @($pipOutput | Where-Object { $_ -match '^Requirement already satisfied' }).Count
                if ($installed.Count -gt 0) {
                    Write-Output "Install successful: $($installed.Count) package(s) installed ($($installed -join ', ')), $satisfied already up to date."
                } else {
                    Write-Output "Install successful: nothing new to install, $satisfied package(s) already up to date."
                }
            }
        }
    }
}

Write-Output ""
Write-Host "Software installation finished." -ForegroundColor Green
