{#- Proxy URL built from proxy.conf (proxy_host, proxy_port, proxy_username, proxy_password),
    with the credentials URL-encoded. Empty if no proxy is set. -#}
{% macro proxy_url() -%}
{%- set host = salt['config.get']('proxy_host', '') -%}
{%- set port = salt['config.get']('proxy_port', '') -%}
{%- set user = salt['config.get']('proxy_username', '') -%}
{%- set password = salt['config.get']('proxy_password', '') -%}
{%- if host and port -%}
http://
{%- if user -%}
{{ user | string | urlencode | replace('/', '%2F') }}:{{ password | string | urlencode | replace('/', '%2F') }}@
{%- endif -%}
{{ host }}:{{ port }}
{%- endif -%}
{%- endmacro %}
