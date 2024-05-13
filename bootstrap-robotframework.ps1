 # Define the local path to save the installer
 $defRFInstallerPath= "C:\RF-Bootstrap"
 $defRepo= "PhilippLemke/robotframework-bootstrap"
 $gitSnap= "$defRFInstallerPath\git-snap"
 
 function Download-Repo {
    param (
        [string]$tmp_folder,
        [string]$repo
    )

    # Define the URL based on the $repo argument
    $url = "https://github.com/$repo/archive/refs/heads/master.zip"
    
    # Construct the output file path
    $outputFilePath = Join-Path -Path $tmp_folder -ChildPath "$($repo.Split('/')[-1]).zip"

    # Download bootstrap git content as zip-file and extract it to tmp
    Invoke-WebRequest -Uri $url -OutFile $outputFilePath
    Expand-Archive -Path $outputFilePath -DestinationPath $tmp_folder -Force
 }

 
 # Define your bootstrap directory structure here
 $directoryStructure = @{
     $defRFInstallerPath = @(
         "salt-app",
         "salt-var",
         "git-snap",
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
 Create-Directories -structure $directoryStructure
 
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
 
 Write-Output "Download and extract the git repository content"
 Download-Repo -tmp_folder $gitSnap -repo $defRepo

 Write-Output "Provide salt-data from git repository to $defRFInstallerPath."
 # Copy salt-data robotframework-bootstrap-master\salt-data to $defRFInstallerPath\.
 Copy-Item -Path "$gitSnap\robotframework-bootstrap-master\salt-data" -Destination $defRFInstallerPath -Recurse -Force
