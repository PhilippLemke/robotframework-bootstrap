 # Define the URL for the Git for Windows installer
 $gitInstallerUrl = "https://github.com/git-for-windows/git/releases/download/v2.44.0.windows.1/Git-2.44.0-64-bit.exe"
 # Define the local path to save the installer
 $gitInstallerPath = "$env:TEMP\git-installer.exe"
 $defRFInstallerPath= "C:\RF-Bootsrap"
 $desiredVersion = "git version 2.44.0"
 
 # Function to check if Git command is available in the PATH
 function Is-GitInPath {
     try {
         $null = Get-Command git -ErrorAction Stop
         return $true
     } catch {
         return $false
     }
 }
 
 # Function to check if the desired version of Git is already installed
 function Is-GitVersionInstalled {
     param (
         [string]$desiredVersion
     )
 
     if (Is-GitInPath) {
         # Attempt to get the version of the currently installed Git
         $installedVersion = & git --version
         if ($installedVersion -like "*$desiredVersion*") {
             return $true
         } else {
             return $false
         }
     } else {
         Write-Output "Git is not available in PATH. Installation may proceed if necessary."
         return $false
     }
 }
 
 # Download and Install Git if the desired version is not already installed
 if (-not (Is-GitVersionInstalled -desiredVersion $desiredVersion)) {
     # Check if the installer is already present in the temp directory
     if (-not (Test-Path -Path $gitInstallerPath)) {
         # Download Git Installer
         Invoke-WebRequest -Uri $gitInstallerUrl -OutFile $gitInstallerPath
         Write-Output "Git installer downloaded."
     } else {
         Write-Output "Git installer already exists in the temp directory."
     }
     
     Start-Process -FilePath $gitInstallerPath -Args "/VERYSILENT" -Wait -NoNewWindow
     Write-Output "Git $desiredVersion has been installed."
 } else {
     Write-Output "The desired version of Git ($desiredVersion) is already installed."
 }
 
 # Define your bootstrap directory structure here
 $directoryStructure = @{
     $defRFInstallerPath = @(
         "salt-app",
         "salt-data\srv\pillar",
         "salt-data\srv\salt",
         "salt-var",
         "pip-pkgs"
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
 Create-Directories -structure $directoryStructure
 
 # Confirm completion
 Write-Output "Git installation and directory structure creation complete."
 
 
 
 # Define source and destination paths
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
 
  
 