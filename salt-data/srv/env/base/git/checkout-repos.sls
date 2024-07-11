{% set git_repos = salt['pillar.get']('git_repos', {} ) %}


{% for repo, options in git_repos.items() %}
{% set target_dir = options.get('target_dir', 'Please specify target_dir in pillars ') %}
{% set target = target_dir + "\\" + repo %}
create-git-target-dir-{{ repo }}:
  file.directory:
    - name: {{ target_dir }}
    - win_owner: {{ salt['grains.get']('username') }}

git-checkout-{{ repo }}:
  git.latest:
    - name: {{ options.get('remote_url', 'Please specify remote_url in Pillar') }}/{{ repo }}
    - target: {{ target }}

{% endfor %}


git_config_safe_directories:
  git.config_set:
    - name: safe.directory
    - global: True
    - multivar:
{% for repo, options in git_repos.items() %}
{% set target_dir = options.get('target_dir', 'Please specify target_dir in pillars ') %}
{% set target = target_dir + "\\" + repo %}
      - {{ target  | replace('\\', '/')  }}
{% endfor %}