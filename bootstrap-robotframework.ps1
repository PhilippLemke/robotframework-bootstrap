param (
    [string]$Proxy,
    [switch]$AlreadyRelaunched,
    [switch]$SkipInstall
)

# Current released version of this script. Bump this by hand every time a new git tag is cut.
$scriptVersion = "v1.1.0"

# Define the local path to save the installer
$defRFInstallerPath = "C:\RF-Bootstrap"
$defRepo = "PhilippLemke/robotframework-bootstrap"
$gitSnap = "$defRFInstallerPath\git-snap"
$cloudConfPath = "$defRFInstallerPath\salt-data\conf\minion.d\cloud.conf"
$cloudConfBackupPath = "$defRFInstallerPath\backup\cloud.conf"
$cloudConfRestored = $false
$rfClientLocalPath = "$defRFInstallerPath\salt-data\srv\pillar\rf-client-local.sls"
$saltCallPath = "$defRFInstallerPath\salt-app\salt-call.exe"
$saltConfDir = "$defRFInstallerPath\salt-data\conf"

# Print a section header to visually group the cmd output
function Write-Section {
    param (
        [string]$Title
    )
    Write-Output ""
    Write-Host "# $Title" -ForegroundColor Cyan
}

# Look up the highest "vX.Y.Z" git tag for $repo via the GitHub API (no git CLI required)
function Get-LatestTag {
    param (
        [string]$repo,
        [string]$Proxy
    )

    $uri = "https://api.github.com/repos/$repo/tags?per_page=100"

    try {
        if ($Proxy) {
            $tags = Invoke-RestMethod -Uri $uri -Proxy $Proxy -ProxyUseDefaultCredentials -Headers @{ "User-Agent" = "robotframework-bootstrap" }
        } else {
            $tags = Invoke-RestMethod -Uri $uri -Headers @{ "User-Agent" = "robotframework-bootstrap" }
        }
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

# Download the newer script and hand execution off to it, so the update is applied by the new
# code instead of this (outdated) run finishing the job. Guarded by -AlreadyRelaunched so a stale
# $scriptVersion can never cause more than one relaunch.
function Invoke-SelfUpdate {
    param (
        [string]$repo,
        [string]$tag,
        [string]$Proxy
    )

    Write-Host "Newer version available: $tag (currently running $scriptVersion). Downloading and relaunching..."

    $newScriptPath = Join-Path $env:TEMP "bootstrap-robotframework-$tag.ps1"
    $newScriptUrl = "https://raw.githubusercontent.com/$repo/$tag/bootstrap-robotframework.ps1"

    try {
        if ($Proxy) {
            Invoke-WebRequest -Uri $newScriptUrl -OutFile $newScriptPath -Proxy $Proxy -ProxyUseDefaultCredentials -ErrorAction Stop
        } else {
            Invoke-WebRequest -Uri $newScriptUrl -OutFile $newScriptPath -ErrorAction Stop
        }
    } catch {
        Write-Host "Failed to download the newer version ($($_.Exception.Message)). Continuing with the current version ($scriptVersion)."
        return $false
    }

    $argString = "-NoProfile -ExecutionPolicy Bypass -File `"$newScriptPath`" -AlreadyRelaunched"
    if ($Proxy) {
        $argString += " -Proxy `"$Proxy`""
    }
    if ($SkipInstall) {
        $argString += " -SkipInstall"
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
        [string]$tag,
        [string]$Proxy
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
        if ($Proxy) {
            Write-Host "Download via Proxy: $Proxy"
            Invoke-WebRequest -Uri $url -OutFile $outputFilePath -Proxy $Proxy -ProxyUseDefaultCredentials -ErrorAction Stop
        } else {
            Write-Host "No Proxy configured, download directly."
            Invoke-WebRequest -Uri $url -OutFile $outputFilePath -ErrorAction Stop
        }

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

# Quick TCP connectivity check against a host:port, with a short timeout. Used both for the proxy
# reachability check and the direct-connection fallback check below.
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

# So a bad proxy fails fast and visibly, with a single clear message, instead of surfacing as a
# cryptic WebException deep inside a download.
function Test-Proxy {
    param (
        [string]$Proxy
    )

    try {
        $uri = [System.Uri]$Proxy
    } catch {
        return $false
    }

    return Test-TcpConnection -ComputerName $uri.Host -Port $uri.Port
}

# Read proxy_host/proxy_port out of an existing cloud.conf, if one is present, so a machine that's
# already configured with a proxy doesn't need -Proxy passed by hand for the update check to work.
function Get-ProxyFromCloudConf {
    param (
        [string]$path
    )

    if (-not (Test-Path -Path $path)) {
        return $null
    }

    $proxyHost = $null
    $proxyPort = $null

    foreach ($line in Get-Content -Path $path) {
        if ($line -match '^\s*proxy_host:\s*(\S+)') {
            $proxyHost = $Matches[1]
        } elseif ($line -match '^\s*proxy_port:\s*(\S+)') {
            $proxyPort = $Matches[1]
        }
    }

    if ($proxyHost -and $proxyPort) {
        return "http://${proxyHost}:${proxyPort}"
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

# If an existing cloud.conf already specifies a proxy and none was passed explicitly, use it for
# the version check and downloads below.
if (-not $Proxy) {
    $detectedProxy = Get-ProxyFromCloudConf -path $cloudConfPath
    if ($detectedProxy) {
        Write-Section "Proxy"
        Write-Output "No -Proxy parameter given; using $detectedProxy from existing cloud.conf."
        $Proxy = $detectedProxy
    }
}

# If a proxy is in use (explicit or detected above), check it's actually reachable before relying
# on it for the version check and downloads below. If it isn't, fall back to a direct connection
# check - if that works, continue without the proxy; if neither works, stop here rather than limp
# through the rest of the run only to fail partway through.
if ($Proxy) {
    Write-Section "Test Connectivity"
    Write-Output "Testing connectivity to $Proxy..."
    Write-Host -NoNewline "Proxy reachable: "
    if (Test-Proxy -Proxy $Proxy) {
        Write-Host "OK" -ForegroundColor Green
    } else {
        Write-Host "FAILED" -ForegroundColor Red
        Write-Output "Could not reach $Proxy within 3 seconds."
        Write-Output ""
        Write-Output "Fallback:"
        Write-Output "Testing connectivity via a direct request https://github.com"
        Write-Host -NoNewline "Github reachable: "
        if (Test-TcpConnection -ComputerName "github.com" -Port 443) {
            Write-Host "OK" -ForegroundColor Green
            Write-Output "Direct connection to github.com works - continuing without the proxy."
            $Proxy = $null
        } else {
            Write-Host "FAILED" -ForegroundColor Red
            Write-Output ""
            Write-Output "Please fix connectivity issues and start deployment again."
            exit 1
        }
    }
}

# Check for a newer released version before doing any real work, and hand off to it if found.
# Skipped on the relaunched (already-updated) run, so a stale $scriptVersion can never cause
# more than one relaunch.
if (-not $AlreadyRelaunched) {
    Write-Section "Version Check"
    $latestTag = Get-LatestTag -repo $defRepo -Proxy $Proxy
    if ($latestTag -and (Test-NewerVersion -tag $latestTag -current $scriptVersion)) {
        if (Invoke-SelfUpdate -repo $defRepo -tag $latestTag -Proxy $Proxy) {
            Write-Output "Relaunched run ($latestTag) finished. Exiting this (outdated) run."
            exit $relaunchExitCode
        }
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
if (-not (Download-Repo -tmp_folder $gitSnap -repo $defRepo -tag $scriptVersion -Proxy $Proxy)) {
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

# Seed the machine-specific pillar overrides after salt-data is in place
New-RfClientLocal

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

$saltSteps = @(
    @("pkg.refresh_db", "saltenv=cloud"),
    @("saltutil.sync_all", "saltenv=cloud"),
    @("state.apply", "deploy-rf-client", "saltenv=cloud", "-l", "info")
)
foreach ($step in $saltSteps) {
    if (-not (Invoke-SaltCall -Arguments $step)) {
        Write-Host "FAILED" -ForegroundColor Red
        Write-Output "salt-call $($step -join ' ') failed. See $defRFInstallerPath\salt-var\salt.log for details."
        exit 1
    }
}

Write-Output ""
Write-Host "Software installation finished." -ForegroundColor Green
