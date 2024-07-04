{% macro download_aws_package(s3_bucket, s3_folder, inst_local_pkg_path) -%}
download-from-cloud-repo:
  cmd.run:
    - name: C:\\Progra~1\\Amazon\\AWSCLIV2\\aws s3 sync s3://{{ s3_bucket }}/{{ s3_folder }} {{ inst_local_pkg_path }}
{%- endmacro %}
