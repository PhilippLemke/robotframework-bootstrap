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