param (
    [string]$Proxy
)
 
 # Define the local path to save the installer
 $defRFInstallerPath= "C:\RF-Bootstrap"
 $defRepo= "PhilippLemke/robotframework-bootstrap"
 $gitSnap= "$defRFInstallerPath\git-snap"
 $cloudConfPath= "$defRFInstallerPath\salt-data\conf\minion.d\cloud.conf"
 $cloudConfBackupPath= "$defRFInstallerPath\backup\cloud.conf"
 $cloudConfRestored= $false


 # Print a section header to visually group the cmd output
 function Write-Section {
     param (
         [string]$Title
     )
     Write-Output ""
     Write-Host "# $Title" -ForegroundColor Cyan
 }

 function Download-Repo {
    param (
        [string]$tmp_folder,
        [string]$repo,
        [string]$Proxy
    )

    # Define the URL based on the $repo argument
    $url = "https://github.com/$repo/archive/refs/heads/master.zip"
    
    # Construct the output file path
    $outputFilePath = Join-Path -Path $tmp_folder -ChildPath "$($repo.Split('/')[-1]).zip"

    # Download bootstrap git content as zip-file and extract it to tmp

    if ($Proxy) {
        Write-Output "Download via Proxy: $Proxy"
        Invoke-WebRequest -Uri $url -OutFile $outputFilePath -Proxy $Proxy -ProxyUseDefaultCredentials
    } else {
        Write-Output "No Proxy configured, download directly."
        Invoke-WebRequest -Uri $url -OutFile $outputFilePath
    }

    Expand-Archive -Path $outputFilePath -DestinationPath $tmp_folder -Force
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
 Write-Output "Download and extract the git repository content"
 Download-Repo -tmp_folder $gitSnap -repo $defRepo -Proxy $Proxy

 Write-Section "Deploy"
 Write-Output "Provide salt-data from git repository to $defRFInstallerPath."
 # Copy salt-data robotframework-bootstrap-master\salt-data to $defRFInstallerPath\.
 Copy-Item -Path "$gitSnap\robotframework-bootstrap-master\salt-data" -Destination $defRFInstallerPath -Recurse -Force

 # Restore a previously backed up cloud.conf over the example one just deployed above
 Restore-CloudConf

 if ($cloudConfRestored) {
     Write-Output ""
     Write-Output "NOTE: An existing cloud.conf was found before this run and has been restored to $cloudConfPath after the bootstrap update."
 }
