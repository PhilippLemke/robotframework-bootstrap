{% set aws_dir = salt['environ.get']('USERPROFILE') ~ '/.aws' %}

create_aws_directory:
  file.directory:
    - name: {{ aws_dir }}
    - makedirs: True
    - user: {{ salt['grains.get']('username') }}
    - require:
      - file: ensure_userprofile_exists

ensure_userprofile_exists:
  file.directory:
    - name: {{ salt['environ.get']('USERPROFILE') }}
    - makedirs: True
    - user: {{ salt['grains.get']('username') }}

manage_aws_credentials:
  file.managed:
    - name: {{ aws_dir + "/credentials" }}
    - source: salt://templates/aws/credentials.jinja
    - template: jinja
    - user: {{ salt['grains.get']('username') }}
    - context:
        aws_access_key_id: {{ salt['config.get']('s3.keyid', 'specify s3.keyid in config') }}
        aws_secret_access_key: {{ salt['config.get']('s3.key', 'specify s3.key in config') }}

manage_aws_config:
  file.managed:
    - name: {{ aws_dir + "/config" }}
    - source: salt://templates/aws/config.jinja
    - template: jinja
    - user: {{ salt['grains.get']('username') }}
    - context:
        aws_region: {{ salt['config.get']('s3.region', 'please specify s3.region in config') }}