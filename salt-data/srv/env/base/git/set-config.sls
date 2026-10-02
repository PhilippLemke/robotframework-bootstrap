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

# Configure git to use the proxy from proxy.conf, or remove it once no proxy is set there
{% from "macros/proxy.sls" import proxy_url with context %}
{% set url = proxy_url() %}

{% for section in ['http', 'https'] %}
{% if url %}
git_config_set_{{ section }}_proxy:
  git.config_set:
    - name: {{ section }}.proxy
    - value: '{{ url }}'
    - global: True
{% else %}
git_config_unset_{{ section }}_proxy:
  git.config_unset:
    - name: {{ section }}.proxy
    - global: True
{% endif %}
{% endfor %}
