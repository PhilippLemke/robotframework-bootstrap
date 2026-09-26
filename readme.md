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

Instead of `-Proxy`, `bootstrap.ps1` also picks up a `$Proxy` variable set in the PowerShell
session (or an environment variable `Proxy`), e.g. `$Proxy = "http://myproxy.local:port"` before
running the one-liner. An explicit `-Proxy` takes precedence.

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
- If cloud.conf configures a proxy (`proxy_host`/`proxy_port`) that is not reachable, the script
  asks whether to install without the proxy for this run or to abort. Continuing writes a
  temporary `minion.d\zz-no-proxy.conf` that overrides the proxy for Salt only while the
  installation runs; cloud.conf itself is not changed.
- If a step fails, the remaining steps are skipped and the script exits with code 1. Details are
  in `C:\RF-Bootstrap\salt-var\salt.log`.
- Pass `-SkipInstall` to `bootstrap.ps1` or `bootstrap-robotframework.ps1` to only deploy
  salt-data, without installing software.

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
(the parameters are ignored) and replacing it with a new one. A new file contains only the S3
settings, so proxy settings from the old one are not carried over.

```powershell
C:\Temp\bootstrap.ps1 -S3Bucket my-bucket
```

#### Machine-specific settings
`salt-data\srv\pillar\rf-client.sls` is overwritten with the release defaults on every run. Put
machine-specific changes (e.g. `client-role`, versions, VS Code extensions) into
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