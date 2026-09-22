# Deploy Robot Framework 

## Windows

### Client with "full" internet access

1. Start Powershell as administrator

#### Bootstrap (recommended)
`bootstrap.ps1` is the single entry point. It resolves the latest released version of this repo
(via a git tag, looked up through the GitHub API), downloads `bootstrap-salt.ps1` and
`bootstrap-robotframework.ps1` from that release, installs Salt if it isn't already present, and
then runs the Robot Framework bootstrap. `bootstrap-robotframework.ps1` also checks on every run
whether a newer release exists and re-launches itself as that version if so, so re-running the
one-liner below always ends up on the current release even if the file cached in `C:\Temp` is old.

```powershell
Invoke-WebRequest -Uri https://github.com/PhilippLemke/robotframework-bootstrap/raw/master/bootstrap.ps1 -OutFile C:\Temp\bootstrap.ps1; C:\Temp\bootstrap.ps1; cmd
```

With a proxy:
```powershell
Invoke-WebRequest -Uri https://github.com/PhilippLemke/robotframework-bootstrap/raw/master/bootstrap.ps1 -OutFile C:\Temp\bootstrap.ps1; C:\Temp\bootstrap.ps1 -Proxy "http://myproxy.local:port"; cmd
```

Install Robot Framework and additional software
```cmd
cd /d C:\RF-Bootstrap\salt-app\

salt-call --local --config-dir=C:\RF-Bootstrap\salt-data\conf saltutil.sync_all
salt-call --local --config-dir=C:\RF-Bootstrap\salt-data\conf state.apply deploy-rf-client
```

#### Bootstrap Robot Framework old fashion way
```powershell
Invoke-WebRequest -Uri https://github.com/PhilippLemke/robotframework-bootstrap/raw/master/bootstrap-robotframework -OutFile C:\Temp\bootstrap-robotframework.ps1
C:\Temp\bootstrap-robotframework.ps1
```

### Releasing a new version
`bootstrap.ps1` and `bootstrap-robotframework.ps1` pick up new releases via git tags, not raw
commits on `master`. To ship a change to clients:

1. Merge the change to `master`.
2. Bump `$scriptVersion` at the top of `bootstrap-robotframework.ps1` to the new tag you're about
   to create (e.g. `v1.1.0`) and commit that.
3. Tag the release and push the tag:
   ```bash
   git tag v1.1.0
   git push origin v1.1.0
   ```

Clients will pick up `v1.1.0` the next time `bootstrap.ps1` is run, or the next time
`bootstrap-robotframework.ps1` runs and detects it's outdated.

###  Build local installer for clients without internet access
This will use the current version of salt to build an local installer

Requirements: 
- Client with internet access




https://github.com/PhilippLemke/robotframework-bootstrap