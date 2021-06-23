write "Bootstrap Robotframework"
$salt_inst_dir = "c:\salt"
$salt_file_root = "srv\salt"
$salt_file_root_path = $salt_inst_dir + "\" + $salt_file_root
$sls_outputfile = $salt_file_root_path + "\deploy-robotframework.sls"


New-Item -Path $salt_inst_dir -Force -Name $salt_file_root -ItemType "directory"
Invoke-WebRequest -Uri https://github.com/PhilippLemke/robotframework-bootstrap/raw/master/salt/deploy-robotframework.sls -OutFile  $sls_outputfile


Start-Process -FilePath "C:\Windows\System32\cmd.exe" -verb runas -ArgumentList {/k c:\salt\bin\python.exe -E -s c:\salt\bin\Scripts\salt-call --local state.apply deploy-robotframework}

