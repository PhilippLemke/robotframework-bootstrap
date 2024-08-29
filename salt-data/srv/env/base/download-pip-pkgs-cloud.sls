{% from "macros/aws.sls" import download_aws_package with context %}

{% set install_mode = salt['config.get']('saltenv', 'public') %}
{% set pip_local_pkg_path = salt['pillar.get']('pip_local_pkg_path', 'set pip_local_pkg_path in pillar') %}
{% set s3_bucket = salt['config.get']('s3.bucket', 'set s3_bucket in pillar cloud.sls') %}

{% if not install_mode == 'cloud' %}
env-local-download:
  test.fail_without_changes:
    - name: Download is only available in the Environments cloud
{% elif install_mode == 'cloud' %}
{{ download_aws_package(s3_bucket, 'pip', pip_local_pkg_path) }}
{% endif %}