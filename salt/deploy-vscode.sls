vscode:
  pkg.installed

{% set vscode_extensions = salt['pillar.get']('vscode:extensions', []) %}

{% for ext in vscode_extensions -%}
install-vscode-ext-{{ ext }}:
  cmd.run:
    - name: >
        "C:\Program Files\Microsoft VS Code\bin\code.cmd" --install-extension {{ ext }}
{% endfor %}
