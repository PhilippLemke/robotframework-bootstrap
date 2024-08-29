{% set install_mode = salt['config.get']('saltenv', 'public') %}
{% set pip_local_pkg_path = salt['pillar.get']('pip_local_pkg_path', 'set pip_local_pkg_path in pillar') %}
{% set s3_bucket = salt['config.get']('s3.bucket', 'set s3_bucket in pillar cloud.sls') %}

{% if install_mode == 'local' %}
env-local-download:
  test.fail_without_changes:
    - name: Download is only available in the Environments public and cloud
{% elif install_mode == 'cloud' %}
download-from-cloud-repo:
  cmd.run:
    - name: aws s3 sync s3://{{s3_bucket}}/pip {{pip_local_pkg_path}}
{% endif %}