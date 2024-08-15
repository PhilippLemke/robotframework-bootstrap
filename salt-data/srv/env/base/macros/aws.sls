{% macro download_aws_package(s3_bucket, s3_folder, inst_local_pkg_path) -%}
# Configure git to use a proxy if configured in salt config
{% set proxy_host = salt['config.get']('proxy_host') %}
{% set proxy_port = salt['config.get']('proxy_port') %}


download-from-cloud-repo:
  cmd.run:
    - name: C:\\Progra~1\\Amazon\\AWSCLIV2\\aws s3 sync s3://{{ s3_bucket }}/{{ s3_folder }} {{ inst_local_pkg_path }}
{% if proxy_host and proxy_port != 0 %}
    - env:
        HTTP_PROXY: http://{{ proxy_host }}:{{ proxy_port }}
        HTTPS_PROXY: http://{{ proxy_host }}:{{ proxy_port }}    
{% endif %}    
{%- endmacro %}
