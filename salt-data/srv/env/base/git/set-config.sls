{% set git_settings = salt['pillar.get']('git_global_settings', {} ) %}

{% for section, options in git_settings.items() %}
  {% for option, value in options.items() %}
git_config_{{ section }}_{{ option }}:
  git.config_set:
    - name: {{ section }}.{{ option }}
    - value: {{ value }}
    - global: True
  {% endfor %}
{% endfor %}

{% set code_commit_endpoint = salt['pillar.get']('code_commit_endpoint', None) %}
{% if code_commit_endpoint %}
set-code-commit-endpoint:
  environ.setenv:
    - name: CODE_COMMIT_ENDPOINT
    - value: {{ code_commit_endpoint }}
    - permanent: HKLM
{% endif %}

# Configure git to use a proxy if configured in salt config
{% set proxy_host = salt['config.get']('proxy_host') %}
{% set proxy_port = salt['config.get']('proxy_port') %}
{% if proxy_host and proxy_port != 0 %}
git_config_set_http_proxy:
  git.config_set:
    - name: http.proxy
    - value: {{ proxy_host }}:{{ proxy_port }}
    - global: True

git_config_set_https_proxy:
  git.config_set:
    - name: https.proxy
    - value: {{ proxy_host }}:{{ proxy_port }} 
    - global: True

{% endif %}