param (
    [string]$Proxy,
    [switch]$AlreadyRelaunched
)

# Current released version of this script. Bump this by hand every time a new git tag is cut.
$scriptVersion = "v1.0.2"

# Define the local path to save the installer
$defRFInstallerPath = "C:\RF-Bootstrap"
$defRepo = "PhilippLemke/robotframework-bootstrap"
$gitSnap = "$defRFInstallerPath\git-snap"
$cloudConfPath = "$defRFInstallerPath\salt-data\conf\minion.d\cloud.conf"
$cloudConfBackupPath = "$defRFInstallerPath\backup\cloud.conf"
$cloudConfRestored = $false

# Print a section header to visually group the cmd output
function Write-Section {
    param (
        [string]$Title
    )
    Write-Output ""
    Write-Host "# $Title" -ForegroundColor Cyan
}

# Look up the most recently created git tag for $repo via the GitHub API (no git CLI required)
function Get-LatestTag {
    param (
        [string]$repo,
        [string]$Proxy
    )

    $uri = "https://api.github.com/repos/$repo/tags"

    try {
        if ($Proxy) {
            return (Invoke-RestMethod -Uri $uri -Proxy $Proxy -ProxyUseDefaultCredentials -Headers @{ "User-Agent" = "robotframework-bootstrap" })[0].name
        } else {
            return (Invoke-RestMethod -Uri $uri -Headers @{ "User-Agent" = "robotframework-bootstrap" })[0].name
        }
    } catch {
        Write-Output "Could not check for a newer version ($($_.Exception.Message)). Continuing with the current version ($scriptVersion)."
        return $null
    }
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

    Write-Output "Newer version available: $tag (currently running $scriptVersion). Downloading and relaunching..."

    $newScriptPath = Join-Path $env:TEMP "bootstrap-robotframework-$tag.ps1"
    $newScriptUrl = "https://raw.githubusercontent.com/$repo/$tag/bootstrap-robotframework.ps1"

    try {
        if ($Proxy) {
            Invoke-WebRequest -Uri $newScriptUrl -OutFile $newScriptPath -Proxy $Proxy -ProxyUseDefaultCredentials
        } else {
            Invoke-WebRequest -Uri $newScriptUrl -OutFile $newScriptPath
        }
    } catch {
        Write-Output "Failed to download the newer version ($($_.Exception.Message)). Continuing with the current version ($scriptVersion)."
        return $false
    }

    $argString = "-NoProfile -ExecutionPolicy Bypass -File `"$newScriptPath`" -AlreadyRelaunched"
    if ($Proxy) {
        $argString += " -Proxy `"$Proxy`""
    }

    Start-Process -FilePath "powershell.exe" -ArgumentList $argString -NoNewWindow
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
            Write-Output "Download via Proxy: $Proxy"
            Invoke-WebRequest -Uri $url -OutFile $outputFilePath -Proxy $Proxy -ProxyUseDefaultCredentials -ErrorAction Stop
        } else {
            Write-Output "No Proxy configured, download directly."
            Invoke-WebRequest -Uri $url -OutFile $outputFilePath -ErrorAction Stop
        }

        Expand-Archive -Path $outputFilePath -DestinationPath $tmp_folder -Force -ErrorAction Stop
    } catch {
        Write-Host "FAILED" -ForegroundColor Red
        Write-Output "Could not download/extract $url ($($_.Exception.Message))."
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

# Do a quick TCP connectivity check against the proxy so a bad proxy fails fast and visibly, with
# a single clear message, instead of surfacing as a cryptic WebException deep inside a download.
function Test-Proxy {
    param (
        [string]$Proxy
    )

    try {
        $uri = [System.Uri]$Proxy
    } catch {
        return $false
    }

    $tcpClient = New-Object System.Net.Sockets.TcpClient
    try {
        $asyncResult = $tcpClient.BeginConnect($uri.Host, $uri.Port, $null, $null)
        return $asyncResult.AsyncWaitHandle.WaitOne(3000) -and $tcpClient.Connected
    } catch {
        return $false
    } finally {
        $tcpClient.Close()
    }
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
# on it for the version check and downloads below.
if ($Proxy) {
    Write-Section "Test Proxy"
    Write-Output "Testing connectivity to $Proxy..."
    Write-Host -NoNewline "Proxy reachable: "
    if (Test-Proxy -Proxy $Proxy) {
        Write-Host "OK" -ForegroundColor Green
    } else {
        Write-Host "FAILED" -ForegroundColor Red
        Write-Output "Could not reach $Proxy within 3 seconds. Continuing anyway, but downloads through this proxy will likely fail."
    }
}

# Check for a newer released version before doing any real work, and hand off to it if found.
# Skipped on the relaunched (already-updated) run, so a stale $scriptVersion can never cause
# more than one relaunch.
if (-not $AlreadyRelaunched) {
    Write-Section "Version Check"
    $latestTag = Get-LatestTag -repo $defRepo -Proxy $Proxy
    if ($latestTag -and $latestTag -ne $scriptVersion) {
        if (Invoke-SelfUpdate -repo $defRepo -tag $latestTag -Proxy $Proxy) {
            Write-Output "Relaunched as $latestTag. Exiting this (outdated) run."
            exit
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
