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

With a proxy (see [Proxy](#proxy)):
```powershell
$px = "http://myproxy.local:port"; Invoke-WebRequest -Uri https://github.com/PhilippLemke/robotframework-bootstrap/raw/master/bootstrap.ps1 -OutFile C:\Temp\bootstrap.ps1 -Proxy $px; C:\Temp\bootstrap.ps1 -Proxy $px; cmd
```

With a proxy that needs a user and password (the same credentials are used for the download of
`bootstrap.ps1` and by the script itself):
```powershell
$px = "http://myproxy.local:port"; $cred = Get-Credential -Message "Proxy"; Invoke-WebRequest -Uri https://github.com/PhilippLemke/robotframework-bootstrap/raw/master/bootstrap.ps1 -OutFile C:\Temp\bootstrap.ps1 -Proxy $px -ProxyCredential $cred; C:\Temp\bootstrap.ps1 -Proxy $px -ProxyCredential $cred; cmd
```

With S3 settings for a new cloud.conf (asks for `s3.keyid` and `s3.key`; see
[S3 settings via parameters](#s3-settings-via-parameters)):
```powershell
Invoke-WebRequest -Uri https://github.com/PhilippLemke/robotframework-bootstrap/raw/master/bootstrap.ps1 -OutFile C:\Temp\bootstrap.ps1; C:\Temp\bootstrap.ps1 -S3Bucket "myBucketName" -S3ServiceUrl "s3.eu-central-1.amazonaws.com" -S3Location "eu-central-1" -S3PathStyle True; cmd
```

With a client role (`coding` or `execution`, saved without asking; see
[Client role](#client-role)):
```powershell
Invoke-WebRequest -Uri https://github.com/PhilippLemke/robotframework-bootstrap/raw/master/bootstrap.ps1 -OutFile C:\Temp\bootstrap.ps1; C:\Temp\bootstrap.ps1 -ClientRole execution; cmd
```

Without syncing and installing the pip packages from S3 (see [Pip packages](#pip-packages)):
```powershell
Invoke-WebRequest -Uri https://github.com/PhilippLemke/robotframework-bootstrap/raw/master/bootstrap.ps1 -OutFile C:\Temp\bootstrap.ps1; C:\Temp\bootstrap.ps1 -SkipPip; cmd
```

#### Proxy
The proxy is defined in one place, `C:\RF-Bootstrap\salt-data\conf\minion.d\proxy.conf`. Salt
reads it as minion config (`proxy_host`, `proxy_port`, `proxy_username`, `proxy_password`), and
the scripts use it for their downloads, the AWS CLI, pip and git (global `.gitconfig`). The
password is stored in plain text, like `s3.key`.

`bootstrap.ps1` sets it up:

| Parameter          | Meaning                                                                      |
|--------------------|------------------------------------------------------------------------------|
| `-Proxy`           | `http://host:port`, `http://user:password@host:port` (URL-encoded) or `none` |
| `-ProxyCredential` | PSCredential for Basic auth, e.g. from `Get-Credential` (`domain\user` works) |
| `-ProxyUser`       | User for Basic auth, as an alternative to `-ProxyCredential`             |
| `-ProxyPassword`   | Password for `-ProxyUser`; asked for (hidden) if missing                 |

Without `-ProxyCredential` or `-ProxyUser` the proxy is used without authentication.

- Without `-Proxy` and without a `proxy.conf`, the script asks for the proxy (Enter = none), then
  for a user (Enter = no authentication) and the password.
- Once `proxy.conf` exists, later runs use it without asking. Pass `-Proxy` again to change it, or
  `-Proxy none` to remove it. "No proxy" is saved as well, so no later run asks again.
- Before a proxy is used, it is tested: TCP connection, then a request to `api.github.com` that
  detects rejected credentials (407). If it fails, you choose between re-entering the proxy,
  continuing without a proxy (saved) and aborting.
- `bootstrap-robotframework.ps1` reads `proxy.conf` and asks the same way on a machine without one.
- Windows logon authentication (NTLM/Kerberos) is not supported, only Basic auth.
- Releases before v1.6.0 kept the proxy in `cloud.conf`. It is moved to `proxy.conf` on the first
  run and removed from `cloud.conf`. The `$Proxy` session variable / `$env:Proxy` fallback is gone.

```powershell
C:\Temp\bootstrap.ps1 -Proxy "http://myproxy.local:3128" -ProxyCredential (Get-Credential)
C:\Temp\bootstrap.ps1 -Proxy "http://myproxy.local:3128" -ProxyUser jdoe
```

`bootstrap.ps1` installs Salt `3006.19` on machines without Salt. Pass `-SaltVersion <version>`
(e.g. `3007.8` or `latest`) for a different one. An existing Salt installation is never upgraded.

A specific release (skips the newer-version check and deploys exactly that tag):
```powershell
Invoke-WebRequest -Uri https://github.com/PhilippLemke/robotframework-bootstrap/raw/master/bootstrap.ps1 -OutFile C:\Temp\bootstrap.ps1; C:\Temp\bootstrap.ps1 -Version v1.0.5; cmd
```
`-Version` also works on `bootstrap-robotframework.ps1` directly. The latest release is the
highest `vX.Y.Z` tag, and the script only self-updates to a release that is newer than itself.

#### Software installation
After deploying salt-data, `bootstrap-robotframework.ps1` installs Robot Framework and the
additional software from the `cloud` Salt environment:

```cmd
cd /d C:\RF-Bootstrap\salt-app\
salt-call --local --config-dir=C:\RF-Bootstrap\salt-data\conf pkg.refresh_db saltenv=cloud
salt-call --local --config-dir=C:\RF-Bootstrap\salt-data\conf saltutil.sync_all saltenv=cloud
salt-call --local --config-dir=C:\RF-Bootstrap\salt-data\conf state.apply deploy-rf-client saltenv=cloud -l info
```

- If `C:\RF-Bootstrap\salt-data\conf\minion.d\cloud.conf` still contains the example
  configuration (empty `s3.keyid`/`s3.key` or bucket `myBucketName`), the script pauses and asks
  you to edit it. Press Enter to re-check, or type `skip` to skip the installation. The script
  then prints the commands above so you can run them later.
- If a step fails, the remaining steps are skipped and the script exits with code 1. Details are
  in `C:\RF-Bootstrap\salt-var\salt.log`.
- Pass `-SkipInstall` to `bootstrap.ps1` or `bootstrap-robotframework.ps1` to only deploy
  salt-data, without installing software.

#### Pip packages
After the Salt steps, the script syncs the pip packages from `s3://<s3.bucket>/pip` to
`C:\RF-Bootstrap\pkgs\pip` with the AWS CLI (credentials from `~/.aws`, written by Salt; proxy
from proxy.conf) and installs them offline:

```cmd
"C:\Program Files\Python310\python.exe" -m pip install --no-index --find-links="C:\RF-Bootstrap\pkgs\pip" -r "C:\RF-Bootstrap\pkgs\pip\requirements.txt"
```

- The Python path comes from `python_home` in the pillar (an override in `rf-client-local.sls` is
  respected).
- Without the AWS CLI, or without a `requirements.txt` in the bucket, the step is skipped with a
  note.
- If the sync or the install fails, the script exits with code 1 and prints the manual fallback
  via Salt (`state.apply download-pip-pkgs-cloud saltenv=cloud`).
- Pass `-SkipPip` to leave this step out.
- By default only a summary is shown (files synced, packages installed); pass `-Verbose` for the
  full output of `aws s3 sync` and `pip`. On a failure the output is always shown.

#### S3 settings via parameters
`bootstrap.ps1` and `bootstrap-robotframework.ps1` can write the S3 settings of `cloud.conf`:

| Parameter       | cloud.conf key   | Default                         |
|-----------------|------------------|---------------------------------|
| `-S3Bucket`     | `s3.bucket`      | none                            |
| `-S3ServiceUrl` | `s3.service_url` | `s3.eu-central-1.amazonaws.com` |
| `-S3Location`   | `s3.location`    | `eu-central-1`                  |
| `-S3PathStyle`  | `s3.path_style`  | `True`                          |

If at least one of them is given, the script writes a new cloud.conf. It asks for the missing
settings (Enter accepts the default in brackets) and always for `s3.keyid` and `s3.key`, which are
never passed as parameters. If a cloud.conf existed before the run, you choose between keeping it
(the parameters are ignored) and replacing it with a new one.

```powershell
C:\Temp\bootstrap.ps1 -S3Bucket my-bucket
```

#### Client role
Before the first software installation, the script asks for the client role (`coding`: Robot
Framework plus VS Code, Greenshot and extensions, the default; `execution`: Robot Framework
runtime only) and saves it in `C:\RF-Bootstrap\salt-data\srv\pillar\client-role.sls`. Later runs
use the saved role without asking. Pass `-ClientRole coding|execution` to set or change it
without the question, e.g. `C:\Temp\bootstrap.ps1 -ClientRole execution`.

An active `client-role:` line in `rf-client-local.sls` overrides the saved role. Changing the role
from coding to execution doesn't uninstall VS Code or Greenshot; Salt only installs what the role
needs.

#### Machine-specific settings
`salt-data\srv\pillar\rf-client.sls` is overwritten with the release defaults on every run. Put
machine-specific changes (e.g. versions, VS Code extensions) into
`C:\RF-Bootstrap\salt-data\srv\pillar\rf-client-local.sls` instead. The script creates it with
commented examples on first run and never overwrites it. Its values override the defaults. Dicts
are merged, lists (e.g. `vscode-extensions`) replace the default list completely.

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