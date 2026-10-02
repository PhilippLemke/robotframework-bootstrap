{% from "macros/proxy.sls" import proxy_url with context %}
{% macro download_aws_package(s3_bucket, s3_folder, inst_local_pkg_path) -%}
{% set url = proxy_url() %}

download-from-cloud-repo:
  cmd.run:
    - name: C:\\Progra~1\\Amazon\\AWSCLIV2\\aws s3 sync s3://{{ s3_bucket }}/{{ s3_folder }} {{ inst_local_pkg_path }}
{% if url %}
    - env:
        HTTP_PROXY: '{{ url }}'
        HTTPS_PROXY: '{{ url }}'
{% endif %}
{%- endmacro %}
